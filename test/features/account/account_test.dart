import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/account/account_gateway.dart';
import 'package:road_runner/features/account/account_models.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/settings/settings_screen.dart';

class _FakePermissionGateway implements PermissionGateway {
  @override
  Future<PermissionSnapshot> check() async => const PermissionSnapshot(
        location: PermissionAccess.granted,
        notification: PermissionAccess.granted,
        locationServicesEnabled: true,
      );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<PermissionAccess> requestLocation() async => PermissionAccess.granted;

  @override
  Future<PermissionAccess> requestNotification() async =>
      PermissionAccess.granted;
}

class _FakeAccountGateway implements AccountGateway {
  final StreamController<AccountUser?> _controller =
      StreamController<AccountUser?>.broadcast();
  AccountUser? _user;
  CloudUserProfile? storedProfile;
  bool shouldFailSignIn = false;

  @override
  AccountUser? get currentUser => _user;

  @override
  Stream<AccountUser?> get authStateChanges => _controller.stream;

  @override
  Future<AccountUser?> signInWithGoogle() async {
    if (shouldFailSignIn) throw Exception('Sign-in failed');
    _user = const AccountUser(
      uid: 'uid-123',
      displayName: 'Praveen Runner',
      email: 'praveen@example.com',
      photoUrl: 'https://example.com/avatar.png',
    );
    storedProfile ??= const CloudUserProfile(
      weeklyGoalKm: 25,
      currentStreakDays: 4,
      longestStreakDays: 7,
      badges: ['first_run', 'first_5k'],
      updatedAtMs: 1700000000000,
    );
    _controller.add(_user);
    return _user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  @override
  Future<CloudUserProfile?> loadProfile(String uid) async => storedProfile;

  @override
  Future<void> saveProfile(AccountUser user, CloudUserProfile profile) async {
    storedProfile = profile;
  }

  @override
  Future<List<CloudBadge>> loadBadges(String uid) async => const [];

  @override
  Future<List<CloudGoal>> loadGoals(String uid) async => const [];

  @override
  Future<void> saveBadge(String uid, CloudBadge badge) async {}

  @override
  Future<void> saveGoal(String uid, CloudGoal goal) async {}
}

void main() {
  group('Account models & Firestore schema mapping', () {
    test('CloudUserProfile clamps fields to firestore.rules bounds', () {
      const user = AccountUser(
        uid: 'u1',
        displayName: 'Test Runner',
        email: 'runner@example.com',
        photoUrl: 'https://example.com/photo.png',
      );
      const profile = CloudUserProfile(
        weeklyGoalKm: 1500,
        currentStreakDays: -3,
        longestStreakDays: 20000,
        badges: ['b1', 'b2'],
        updatedAtMs: 123456,
      );

      final map = profile.toFirestoreMap(user);
      expect(map['displayName'], 'Test Runner');
      expect(map['email'], 'runner@example.com');
      expect(map['photoUrl'], 'https://example.com/photo.png');
      expect(map['weeklyGoalKm'], 1000.0);
      expect(map['currentStreakDays'], 0);
      expect(map['longestStreakDays'], 10000);
      expect(map['badges'], ['b1', 'b2']);
      expect(map['updatedAt'], 123456);

      final restored = CloudUserProfile.fromMap(map);
      expect(restored.weeklyGoalKm, 1000.0);
      expect(restored.badges, ['b1', 'b2']);
    });

    test('CloudGoal and CloudBadge round-trip cleanly', () {
      const goal = CloudGoal(
        id: 'weekly',
        title: 'Run 20 km this week',
        targetKm: 20.0,
        period: 'weekly',
        updatedAtMs: 999,
      );
      final restoredGoal = CloudGoal.fromMap('weekly', goal.toFirestoreMap());
      expect(restoredGoal.title, 'Run 20 km this week');
      expect(restoredGoal.targetKm, 20.0);
      expect(restoredGoal.period, 'weekly');

      const badge = CloudBadge(id: 'first_5k', earnedAtMs: 888);
      final restoredBadge = CloudBadge.fromMap('first_5k', badge.toFirestoreMap());
      expect(restoredBadge.id, 'first_5k');
      expect(restoredBadge.earnedAtMs, 888);
    });
  });

  group('SettingsScreen Account & Cloud Sync', () {
    testWidgets('sign in with Google, show synced stats, and sign out', (
      tester,
    ) async {
      final accountGateway = _FakeAccountGateway();
      AccountUser? user;
      CloudUserProfile? profile;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StatefulBuilder(
            builder: (context, setState) => SettingsScreen(
              gateway: _FakePermissionGateway(),
              onBack: () {},
              onOpenHome: () {},
              onOpenHistory: () {},
              onManagePermissions: () {},
              accountUser: user,
              accountProfile: profile,
              onSignInWithGoogle: () async {
                final signedIn = await accountGateway.signInWithGoogle();
                final loaded = signedIn == null
                    ? null
                    : await accountGateway.loadProfile(signedIn.uid);
                setState(() {
                  user = signedIn;
                  profile = loaded;
                });
              },
              onSignOut: () async {
                await accountGateway.signOut();
                setState(() {
                  user = null;
                  profile = null;
                });
              },
              onSyncAccount: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsScreen.signInButtonKey), findsOneWidget);
      await tester.tap(find.byKey(SettingsScreen.signInButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Praveen Runner'), findsOneWidget);
      expect(find.text('praveen@example.com'), findsOneWidget);
      expect(
        find.text('Weekly goal: 25 km • Streak: 4d • Badges: 2'),
        findsOneWidget,
      );
      expect(find.byKey(SettingsScreen.signOutButtonKey), findsOneWidget);

      await tester.tap(find.byKey(SettingsScreen.signOutButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsScreen.signInButtonKey), findsOneWidget);
    });
  });
}
