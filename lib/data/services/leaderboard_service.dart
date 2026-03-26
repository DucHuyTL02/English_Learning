import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.avatarEmoji,
    required this.totalXp,
    required this.currentStreak,
    required this.achievementsUnlocked,
    required this.updatedAt,
  });

  final int userId;
  final String displayName;
  final String avatarEmoji;
  final int totalXp;
  final int currentStreak;
  final int achievementsUnlocked;
  final DateTime updatedAt;

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    final ts = map['updatedAt'];
    final updated = ts is Timestamp ? ts.toDate() : DateTime.now();

    return LeaderboardEntry(
      userId: (map['userId'] as num?)?.toInt() ?? 0,
      displayName: (map['displayName'] as String?) ?? 'Bạn',
      avatarEmoji: (map['avatarEmoji'] as String?) ?? '👤',
      totalXp: (map['totalXp'] as num?)?.toInt() ?? 0,
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      achievementsUnlocked: (map['achievementsUnlocked'] as num?)?.toInt() ?? 0,
      updatedAt: updated,
    );
  }
}

class LeaderboardService {
  LeaderboardService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _collection = 'leaderboard_users';

  Future<void> upsertUserEntry({
    required int userId,
    required String displayName,
    required String avatarEmoji,
    required int totalXp,
    required int currentStreak,
    required int achievementsUnlocked,
  }) async {
    try {
      await _firestore.collection(_collection).doc(userId.toString()).set({
        'userId': userId,
        'displayName': displayName,
        'avatarEmoji': avatarEmoji,
        'totalXp': totalXp,
        'currentStreak': currentStreak,
        'achievementsUnlocked': achievementsUnlocked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Keep app usable when offline or Firestore is not configured yet.
    }
  }

  Future<List<LeaderboardEntry>> fetchTopUsers({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('totalXp', descending: true)
          .orderBy('currentStreak', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => LeaderboardEntry.fromMap(doc.data()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
