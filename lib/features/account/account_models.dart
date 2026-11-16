import 'package:flutter/foundation.dart';

/// Signed-in user identity from Firebase Auth / Google Sign-In.
@immutable
class AccountUser {
  const AccountUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
}

/// Cloud-synced profile, streak, and badge summary stored at `users/{uid}`.
@immutable
class CloudUserProfile {
  const CloudUserProfile({
    this.weeklyGoalKm = 20.0,
    this.currentStreakDays = 0,
    this.longestStreakDays = 0,
    this.badges = const <String>[],
    required this.updatedAtMs,
  });

  final double weeklyGoalKm;
  final int currentStreakDays;
  final int longestStreakDays;
  final List<String> badges;
  final int updatedAtMs;

  CloudUserProfile copyWith({
    double? weeklyGoalKm,
    int? currentStreakDays,
    int? longestStreakDays,
    List<String>? badges,
    int? updatedAtMs,
  }) {
    return CloudUserProfile(
      weeklyGoalKm: weeklyGoalKm ?? this.weeklyGoalKm,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      longestStreakDays: longestStreakDays ?? this.longestStreakDays,
      badges: badges ?? this.badges,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  /// Serializes to the exact field set allowed by `firestore.rules`.
  Map<String, Object?> toFirestoreMap(AccountUser user) {
    final String name = (user.displayName ?? '').trim();
    final String email = (user.email ?? '').trim();
    final String photo = (user.photoUrl ?? '').trim();
    return <String, Object?>{
      if (name.isNotEmpty)
        'displayName': name.length > 100 ? name.substring(0, 100) : name,
      if (email.isNotEmpty)
        'email': email.length > 200 ? email.substring(0, 200) : email,
      if (photo.isNotEmpty &&
          (photo.startsWith('https://') || photo.startsWith('http://')))
        'photoUrl': photo.length > 500 ? photo.substring(0, 500) : photo,
      'weeklyGoalKm': weeklyGoalKm.clamp(0.0, 1000.0),
      'currentStreakDays': currentStreakDays.clamp(0, 10000),
      'longestStreakDays': longestStreakDays.clamp(0, 10000),
      'badges': badges.take(50).toList(),
      'updatedAt': updatedAtMs,
    };
  }

  factory CloudUserProfile.fromMap(Map<String, Object?> map) {
    final rawBadges = map['badges'];
    final List<String> badgeList = rawBadges is List
        ? rawBadges.whereType<String>().take(50).toList()
        : const <String>[];

    final rawUpdated = map['updatedAt'];
    final int updatedAtMs = rawUpdated is int
        ? rawUpdated
        : DateTime.now().millisecondsSinceEpoch;

    return CloudUserProfile(
      weeklyGoalKm: (map['weeklyGoalKm'] as num?)?.toDouble() ?? 20.0,
      currentStreakDays: (map['currentStreakDays'] as num?)?.toInt() ?? 0,
      longestStreakDays: (map['longestStreakDays'] as num?)?.toInt() ?? 0,
      badges: badgeList,
      updatedAtMs: updatedAtMs,
    );
  }
}

/// Goal document stored at `users/{uid}/goals/{goalId}`.
@immutable
class CloudGoal {
  const CloudGoal({
    required this.id,
    required this.title,
    required this.targetKm,
    required this.period,
    required this.updatedAtMs,
  });

  final String id;
  final String title;
  final double targetKm;
  final String period; // 'weekly' | 'monthly' | 'custom'
  final int updatedAtMs;

  Map<String, Object?> toFirestoreMap() {
    final String safePeriod =
        (period == 'weekly' || period == 'monthly' || period == 'custom')
            ? period
            : 'weekly';
    final String trimmed = title.trim();
    return <String, Object?>{
      'title': trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed,
      'targetKm': targetKm.clamp(0.1, 10000.0),
      'period': safePeriod,
      'updatedAt': updatedAtMs,
    };
  }

  factory CloudGoal.fromMap(String id, Map<String, Object?> map) {
    final rawUpdated = map['updatedAt'];
    return CloudGoal(
      id: id,
      title: (map['title'] as String?) ?? 'Weekly goal',
      targetKm: (map['targetKm'] as num?)?.toDouble() ?? 20.0,
      period: (map['period'] as String?) ?? 'weekly',
      updatedAtMs: rawUpdated is int
          ? rawUpdated
          : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Earned badge document stored at `users/{uid}/badges/{badgeId}`.
@immutable
class CloudBadge {
  const CloudBadge({required this.id, required this.earnedAtMs});

  final String id;
  final int earnedAtMs;

  Map<String, Object?> toFirestoreMap() => <String, Object?>{
    'id': id.length > 64 ? id.substring(0, 64) : id,
    'earnedAt': earnedAtMs,
  };

  factory CloudBadge.fromMap(String docId, Map<String, Object?> map) {
    final rawEarned = map['earnedAt'];
    return CloudBadge(
      id: (map['id'] as String?) ?? docId,
      earnedAtMs: rawEarned is int
          ? rawEarned
          : DateTime.now().millisecondsSinceEpoch,
    );
  }
}
