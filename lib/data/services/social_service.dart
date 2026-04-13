import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class SocialServiceException implements Exception {
  SocialServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SocialUserProfile {
  const SocialUserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.avatarEmoji,
    required this.totalXp,
    required this.streak,
  });

  final String uid;
  final String fullName;
  final String email;
  final String avatarEmoji;
  final int totalXp;
  final int streak;
}

class RankedSocialUser extends SocialUserProfile {
  const RankedSocialUser({
    required this.rank,
    required this.isCurrentUser,
    required super.uid,
    required super.fullName,
    required super.email,
    required super.avatarEmoji,
    required super.totalXp,
    required super.streak,
  });

  final int rank;
  final bool isCurrentUser;
}

class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.toName,
    required this.fromEmail,
    required this.toEmail,
    required this.fromAvatarEmoji,
    required this.toAvatarEmoji,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String fromUid;
  final String toUid;
  final String fromName;
  final String toName;
  final String fromEmail;
  final String toEmail;
  final String fromAvatarEmoji;
  final String toAvatarEmoji;
  final String status;
  final DateTime createdAt;

  bool isIncomingFor(String currentUid) => toUid == currentUid;
  bool isOutgoingFor(String currentUid) => fromUid == currentUid;
}

class SocialService {
  SocialService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';
  static const String _friendsCollection = 'friends';
  static const String _friendRequestsCollection = 'friend_requests';
  static const String _statusPending = 'pending';
  static const String _statusAccepted = 'accepted';
  static final RegExp _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    caseSensitive: false,
  );

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(_usersCollection);
  CollectionReference<Map<String, dynamic>> get _friendRequestsRef =>
      _firestore.collection(_friendRequestsCollection);

  CollectionReference<Map<String, dynamic>> _friendsRef(String userUid) =>
      _usersRef.doc(userUid).collection(_friendsCollection);

  Future<List<RankedSocialUser>> getGlobalLeaderboard({int limit = 100}) async {
    final safeLimit = limit < 1 ? 1 : limit;
    final fetchLimit = safeLimit > 300 ? safeLimit : 300;
    try {
      final currentUid = _requireCurrentUid();
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _usersRef
            .orderBy('xp', descending: true)
            .limit(fetchLimit)
            .get();
      } on FirebaseException {
        snapshot = await _usersRef.limit(fetchLimit).get();
      }
      final users = snapshot.docs.map(_toProfile).toList();
      return _rankUsers(users, currentUid, limit: safeLimit);
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the tai bang xep hang toan cau.');
    } catch (_) {
      throw SocialServiceException('Khong the tai bang xep hang toan cau.');
    }
  }

  Future<List<RankedSocialUser>> getFriendsLeaderboard({
    int limit = 100,
  }) async {
    final safeLimit = limit < 1 ? 1 : limit;
    try {
      final currentUid = _requireCurrentUid();
      final friendIds = await getFriendUidSet();
      final userIds = <String>{currentUid, ...friendIds}.toList();
      final users = await _fetchUsersByIds(userIds);
      return _rankUsers(users, currentUid, limit: safeLimit);
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the tai bang xep hang ban be.');
    } catch (_) {
      throw SocialServiceException('Khong the tai bang xep hang ban be.');
    }
  }

  Future<Set<String>> getFriendUidSet() async {
    try {
      final currentUid = _requireCurrentUid();
      final friendUidSet = <String>{};

      final legacySnapshot = await _friendsRef(currentUid).get();
      for (final doc in legacySnapshot.docs) {
        friendUidSet.add(doc.id);
      }

      final acceptedOutgoing = await _friendRequestsRef
          .where('fromUid', isEqualTo: currentUid)
          .where('status', isEqualTo: _statusAccepted)
          .get();
      for (final doc in acceptedOutgoing.docs) {
        final toUid = _readString(doc.data(), 'toUid');
        if (toUid.isNotEmpty) {
          friendUidSet.add(toUid);
        }
      }

      final acceptedIncoming = await _friendRequestsRef
          .where('toUid', isEqualTo: currentUid)
          .where('status', isEqualTo: _statusAccepted)
          .get();
      for (final doc in acceptedIncoming.docs) {
        final fromUid = _readString(doc.data(), 'fromUid');
        if (fromUid.isNotEmpty) {
          friendUidSet.add(fromUid);
        }
      }

      return friendUidSet;
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the tai danh sach ban be.');
    } catch (_) {
      throw SocialServiceException('Khong the tai danh sach ban be.');
    }
  }

  Future<SocialUserProfile?> findUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw SocialServiceException('Vui long nhap email de tim kiem.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw SocialServiceException('Email khong dung dinh dang.');
    }

    try {
      final currentUid = _requireCurrentUid();
      final snapshot = await _usersRef
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final user = _toProfile(snapshot.docs.first);
      if (user.uid == currentUid) {
        throw SocialServiceException(
          'Ban khong the tu ket ban voi chinh minh.',
        );
      }
      return user;
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the tim tai khoan theo email.');
    } catch (_) {
      throw SocialServiceException('Khong the tim tai khoan theo email.');
    }
  }

  Future<void> addFriendByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw SocialServiceException('Vui long nhap email de ket ban.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw SocialServiceException('Email khong dung dinh dang.');
    }

    try {
      final currentUid = _requireCurrentUid();
      final currentEmail = (_auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
      if (currentEmail.isNotEmpty && currentEmail == normalizedEmail) {
        throw SocialServiceException(
          'Ban khong the tu ket ban voi chinh minh.',
        );
      }

      final target = await findUserByEmail(normalizedEmail);
      if (target == null) {
        throw SocialServiceException('Khong tim thay tai khoan voi email nay.');
      }

      final friendRef = _friendsRef(currentUid).doc(target.uid);
      final exists = await friendRef.get();
      if (exists.exists) {
        throw SocialServiceException('Nguoi nay da co trong danh sach ban.');
      }

      await friendRef.set({
        'uid': target.uid,
        'email': target.email,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the them ban luc nay.');
    } catch (_) {
      throw SocialServiceException('Khong the them ban luc nay.');
    }
  }

  Future<List<SocialUserProfile>> getFriends() async {
    try {
      final friendIds = await getFriendUidSet();
      final profiles = await _fetchUsersByIds(friendIds.toList());
      profiles.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
      return profiles;
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the tai danh sach ban be.');
    } catch (_) {
      throw SocialServiceException('Khong the tai danh sach ban be.');
    }
  }

  Future<void> sendFriendRequestByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw SocialServiceException('Vui long nhap email de gui loi moi.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw SocialServiceException('Email khong dung dinh dang.');
    }

    try {
      final currentUid = _requireCurrentUid();
      final currentUser = _auth.currentUser;
      final target = await findUserByEmail(normalizedEmail);
      if (target == null) {
        throw SocialServiceException('Khong tim thay tai khoan voi email nay.');
      }

      final friendUidSet = await getFriendUidSet();
      if (friendUidSet.contains(target.uid)) {
        throw SocialServiceException('Nguoi nay da co trong danh sach ban.');
      }

      final outgoingId = _requestId(fromUid: currentUid, toUid: target.uid);
      final incomingId = _requestId(fromUid: target.uid, toUid: currentUid);

      final outgoingDoc = await _friendRequestsRef.doc(outgoingId).get();
      if (outgoingDoc.exists) {
        throw SocialServiceException('Ban da gui loi moi cho nguoi nay.');
      }

      final incomingDoc = await _friendRequestsRef.doc(incomingId).get();
      if (incomingDoc.exists) {
        throw SocialServiceException(
          'Nguoi nay da gui loi moi cho ban. Hay vao tab loi moi de chap nhan.',
        );
      }

      final currentEmail = (currentUser?.email ?? '').trim().toLowerCase();
      final currentName = (currentUser?.displayName ?? '').trim().isNotEmpty
          ? currentUser!.displayName!.trim()
          : _fallbackNameFromEmail(currentEmail);
      final currentProfileDoc = await _usersRef.doc(currentUid).get();
      final currentAvatarEmoji = _readString(
        currentProfileDoc.data(),
        'avatarEmoji',
        fallback: '🙂',
      );

      await _friendRequestsRef.doc(outgoingId).set({
        'id': outgoingId,
        'fromUid': currentUid,
        'toUid': target.uid,
        'fromEmail': currentEmail,
        'toEmail': target.email,
        'fromName': currentName,
        'toName': target.fullName,
        'fromAvatarEmoji': currentAvatarEmoji,
        'toAvatarEmoji': target.avatarEmoji,
        'status': _statusPending,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the gui loi moi ket ban luc nay.');
    } catch (_) {
      throw SocialServiceException('Khong the gui loi moi ket ban luc nay.');
    }
  }

  Future<List<FriendRequestItem>> getIncomingFriendRequests() async {
    try {
      final currentUid = _requireCurrentUid();
      final snapshot = await _friendRequestsRef
          .where('toUid', isEqualTo: currentUid)
          .where('status', isEqualTo: _statusPending)
          .get();
      final requests = snapshot.docs.map(_toFriendRequest).toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the tai loi moi da nhan.');
    } catch (_) {
      throw SocialServiceException('Khong the tai loi moi da nhan.');
    }
  }

  Future<List<FriendRequestItem>> getOutgoingFriendRequests() async {
    try {
      final currentUid = _requireCurrentUid();
      final snapshot = await _friendRequestsRef
          .where('fromUid', isEqualTo: currentUid)
          .where('status', isEqualTo: _statusPending)
          .get();
      final requests = snapshot.docs.map(_toFriendRequest).toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the tai loi moi da gui.');
    } catch (_) {
      throw SocialServiceException('Khong the tai loi moi da gui.');
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) {
      throw SocialServiceException('Loi moi ket ban khong hop le.');
    }

    try {
      final currentUid = _requireCurrentUid();
      final requestDoc = await _friendRequestsRef.doc(trimmedId).get();
      if (!requestDoc.exists) {
        throw SocialServiceException('Loi moi nay da khong con ton tai.');
      }
      final request = _toFriendRequest(requestDoc);
      if (!request.isIncomingFor(currentUid)) {
        throw SocialServiceException(
          'Ban khong co quyen chap nhan loi moi nay.',
        );
      }
      if (request.status != _statusPending) {
        throw SocialServiceException('Loi moi nay khong con o trang thai cho.');
      }

      await _friendRequestsRef.doc(trimmedId).set({
        'status': _statusAccepted,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the chap nhan loi moi luc nay.');
    } catch (_) {
      throw SocialServiceException('Khong the chap nhan loi moi luc nay.');
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _deleteRequest(
      requestId,
      validation: (request, currentUid) => request.isIncomingFor(currentUid),
      noPermissionMessage: 'Ban khong co quyen tu choi loi moi nay.',
    );
  }

  Future<void> cancelFriendRequest(String requestId) async {
    await _deleteRequest(
      requestId,
      validation: (request, currentUid) => request.isOutgoingFor(currentUid),
      noPermissionMessage: 'Ban khong co quyen huy loi moi nay.',
    );
  }

  Future<void> syncCurrentUserStats({
    required int totalXp,
    required int streak,
    UserModel? localUser,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) return;

    final resolvedEmail = (authUser.email ?? localUser?.email ?? '')
        .trim()
        .toLowerCase();
    if (resolvedEmail.isEmpty) return;

    final authName = (authUser.displayName ?? '').trim();
    final localName = (localUser?.displayName ?? '').trim();
    final resolvedName = authName.isNotEmpty
        ? authName
        : localName.isNotEmpty
        ? localName
        : _fallbackNameFromEmail(resolvedEmail);

    final avatarEmoji = (localUser?.avatarEmoji ?? '').trim().isNotEmpty
        ? localUser!.avatarEmoji
        : '🙂';

    await _usersRef.doc(authUser.uid).set({
      'id': authUser.uid,
      'uid': authUser.uid,
      'hoTen': resolvedName,
      'fullName': resolvedName,
      'email': resolvedEmail,
      'avatarEmoji': avatarEmoji,
      'xp': totalXp,
      'totalXp': totalXp,
      'level': _levelFromXp(totalXp),
      'streak': streak,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _requireCurrentUid() {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw SocialServiceException(
        'Phien dang nhap da het han. Vui long dang nhap lai.',
      );
    }
    return authUser.uid;
  }

  Future<void> _deleteRequest(
    String requestId, {
    required bool Function(FriendRequestItem request, String currentUid)
    validation,
    required String noPermissionMessage,
  }) async {
    final trimmedId = requestId.trim();
    if (trimmedId.isEmpty) {
      throw SocialServiceException('Loi moi ket ban khong hop le.');
    }
    try {
      final currentUid = _requireCurrentUid();
      final requestDoc = await _friendRequestsRef.doc(trimmedId).get();
      if (!requestDoc.exists) return;
      final request = _toFriendRequest(requestDoc);
      if (!validation(request, currentUid)) {
        throw SocialServiceException(noPermissionMessage);
      }
      if (request.status != _statusPending) {
        throw SocialServiceException('Loi moi nay khong con o trang thai cho.');
      }
      await _friendRequestsRef.doc(trimmedId).delete();
    } on SocialServiceException {
      rethrow;
    } on FirebaseException catch (_) {
      throw SocialServiceException('Khong the xu ly loi moi luc nay.');
    } catch (_) {
      throw SocialServiceException('Khong the xu ly loi moi luc nay.');
    }
  }

  Future<List<SocialUserProfile>> _fetchUsersByIds(List<String> ids) async {
    final uniqueIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return [];

    const chunkSize = 10;
    final byUid = <String, SocialUserProfile>{};
    for (var i = 0; i < uniqueIds.length; i += chunkSize) {
      final end = i + chunkSize < uniqueIds.length
          ? i + chunkSize
          : uniqueIds.length;
      final chunk = uniqueIds.sublist(i, end);
      final snapshot = await _usersRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final profile = _toProfile(doc);
        byUid[profile.uid] = profile;
      }
    }
    return byUid.values.toList();
  }

  SocialUserProfile _toProfile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final email = _readString(data, 'email');
    final fullName = _readString(
      data,
      'hoTen',
      fallback: _readString(
        data,
        'fullName',
        fallback: _fallbackNameFromEmail(email),
      ),
    );
    return SocialUserProfile(
      uid: doc.id,
      fullName: fullName,
      email: email,
      avatarEmoji: _readString(data, 'avatarEmoji', fallback: '🙂'),
      totalXp: _readInt(data, 'xp', fallback: _readInt(data, 'totalXp')),
      streak: _readInt(data, 'streak'),
    );
  }

  FriendRequestItem _toFriendRequest(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAtValue = data?['createdAt'];
    DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is String) {
      createdAt =
          DateTime.tryParse(createdAtValue) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    }

    return FriendRequestItem(
      id: doc.id,
      fromUid: _readString(data, 'fromUid'),
      toUid: _readString(data, 'toUid'),
      fromName: _readString(data, 'fromName'),
      toName: _readString(data, 'toName'),
      fromEmail: _readString(data, 'fromEmail'),
      toEmail: _readString(data, 'toEmail'),
      fromAvatarEmoji: _readString(data, 'fromAvatarEmoji', fallback: '🙂'),
      toAvatarEmoji: _readString(data, 'toAvatarEmoji', fallback: '🙂'),
      status: _readString(data, 'status', fallback: _statusPending),
      createdAt: createdAt,
    );
  }

  List<RankedSocialUser> _rankUsers(
    List<SocialUserProfile> users,
    String currentUid, {
    required int limit,
  }) {
    final sorted = [...users]
      ..sort((a, b) {
        final xpCompare = b.totalXp.compareTo(a.totalXp);
        if (xpCompare != 0) return xpCompare;
        final streakCompare = b.streak.compareTo(a.streak);
        if (streakCompare != 0) return streakCompare;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });

    final trimmed = sorted.take(limit).toList();
    return List.generate(trimmed.length, (index) {
      final user = trimmed[index];
      return RankedSocialUser(
        rank: index + 1,
        isCurrentUser: user.uid == currentUid,
        uid: user.uid,
        fullName: user.fullName,
        email: user.email,
        avatarEmoji: user.avatarEmoji,
        totalXp: user.totalXp,
        streak: user.streak,
      );
    });
  }

  String _readString(
    Map<String, dynamic>? data,
    String key, {
    String fallback = '',
  }) {
    if (data == null) return fallback;
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  int _readInt(Map<String, dynamic>? data, String key, {int fallback = 0}) {
    if (data == null) return fallback;
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String _fallbackNameFromEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) return 'Ban';
    final atIndex = normalized.indexOf('@');
    if (atIndex <= 0) return normalized;
    return normalized.substring(0, atIndex);
  }

  int _levelFromXp(int xp) {
    if (xp <= 0) return 1;
    return (xp ~/ 500) + 1;
  }

  String _requestId({required String fromUid, required String toUid}) {
    return '${fromUid.trim()}_${toUid.trim()}';
  }
}
