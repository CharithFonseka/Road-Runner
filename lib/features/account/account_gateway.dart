import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'account_models.dart';

/// Abstraction over Firebase Auth, Google Sign-In, and Cloud Firestore
/// so tests can inject a fake without initializing native Firebase.
abstract class AccountGateway {
  AccountUser? get currentUser;
  Stream<AccountUser?> get authStateChanges;

  /// Triggers Google Sign-In and links to Firebase Auth.
  /// Returns null if the user cancels the sign-in flow.
  Future<AccountUser?> signInWithGoogle();

  Future<void> signOut();

  Future<CloudUserProfile?> loadProfile(String uid);
  Future<void> saveProfile(AccountUser user, CloudUserProfile profile);

  Future<List<CloudGoal>> loadGoals(String uid);
  Future<void> saveGoal(String uid, CloudGoal goal);

  Future<List<CloudBadge>> loadBadges(String uid);
  Future<void> saveBadge(String uid, CloudBadge badge);
}

/// Production [AccountGateway] backed by Firebase Auth, Google Sign-In v7,
/// and Cloud Firestore (free-tier only).
class FirebaseAccountGateway implements AccountGateway {
  FirebaseAccountGateway({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  Future<void>? _googleInitFuture;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitFuture ??= GoogleSignIn.instance.initialize();
  }

  static AccountUser? _mapUser(User? user) {
    if (user == null) return null;
    return AccountUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }

  @override
  AccountUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AccountUser?> get authStateChanges =>
      _auth.authStateChanges().map(_mapUser);

  @override
  Future<AccountUser?> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final GoogleSignInAccount googleAccount;
    try {
      googleAccount = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }

    final String? idToken = googleAccount.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google Sign-In did not return an ID token.');
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: idToken,
    );
    final UserCredential userCred = await _auth.signInWithCredential(
      credential,
    );
    final AccountUser? accountUser = _mapUser(userCred.user);
    if (accountUser == null) {
      throw StateError('Firebase sign-in returned no user.');
    }

    // Ensure a profile document exists in Firestore without overwriting existing stats.
    final CloudUserProfile? existing = await loadProfile(accountUser.uid);
    final CloudUserProfile profile = existing ??
        CloudUserProfile(updatedAtMs: DateTime.now().millisecondsSinceEpoch);
    await saveProfile(accountUser, profile);
    return accountUser;
  }

  @override
  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await _auth.signOut();
    await GoogleSignIn.instance.signOut();
  }

  DocumentReference<Map<String, Object?>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<CloudUserProfile?> loadProfile(String uid) async {
    final DocumentSnapshot<Map<String, Object?>> snap =
        await _userDoc(uid).get();
    final Map<String, Object?>? data = snap.data();
    if (!snap.exists || data == null) return null;
    return CloudUserProfile.fromMap(data);
  }

  @override
  Future<void> saveProfile(AccountUser user, CloudUserProfile profile) async {
    await _userDoc(user.uid).set(
      profile.toFirestoreMap(user),
      SetOptions(merge: true),
    );
  }

  @override
  Future<List<CloudGoal>> loadGoals(String uid) async {
    final QuerySnapshot<Map<String, Object?>> snap =
        await _userDoc(uid).collection('goals').get();
    return snap.docs
        .map((doc) => CloudGoal.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> saveGoal(String uid, CloudGoal goal) async {
    await _userDoc(uid)
        .collection('goals')
        .doc(goal.id)
        .set(goal.toFirestoreMap(), SetOptions(merge: true));
  }

  @override
  Future<List<CloudBadge>> loadBadges(String uid) async {
    final QuerySnapshot<Map<String, Object?>> snap =
        await _userDoc(uid).collection('badges').get();
    return snap.docs
        .map((doc) => CloudBadge.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<void> saveBadge(String uid, CloudBadge badge) async {
    await _userDoc(uid)
        .collection('badges')
        .doc(badge.id)
        .set(badge.toFirestoreMap(), SetOptions(merge: true));
  }
}
