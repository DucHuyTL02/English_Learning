import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_topic_model.dart';

/// Exception thrown by [UserTopicService].
class UserTopicServiceException implements Exception {
  UserTopicServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Service for managing user-created vocabulary topics on Firestore.
///
/// Firestore structure:
/// ```
///   users/{userId}/topics/{topicId}
///   users/{userId}/topics/{topicId}/words/{wordId}
/// ```
class UserTopicService {
  UserTopicService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // ─── helpers ───────────────────────────────────────────────────────

  String get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      throw UserTopicServiceException(
        'Bạn cần đăng nhập để sử dụng tính năng này.',
      );
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _topicsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('topics');

  CollectionReference<Map<String, dynamic>> _wordsCol(
    String userId,
    String topicId,
  ) => _topicsCol(userId).doc(topicId).collection('words');

  // ─── Topics CRUD ──────────────────────────────────────────────────

  /// Fetches all topics for the currently signed-in user.
  Future<List<UserTopicModel>> getTopics() async {
    try {
      final userId = _currentUserId;
      final snapshot = await _topicsCol(
        userId,
      ).orderBy('createdAt', descending: true).get();
      return snapshot.docs
          .map((doc) => UserTopicModel.fromMap(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw UserTopicServiceException('Firebase error: ${e.code}.');
    } on UserTopicServiceException {
      rethrow;
    } catch (_) {
      throw UserTopicServiceException('Không thể tải danh sách chủ đề.');
    }
  }

  /// Creates a new topic and returns its model.
  Future<UserTopicModel> createTopic(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw UserTopicServiceException('Tên chủ đề không được để trống.');
    }

    try {
      final userId = _currentUserId;
      final docRef = _topicsCol(userId).doc();
      final now = DateTime.now();
      final topic = UserTopicModel(
        id: docRef.id,
        userId: userId,
        name: trimmedName,
        createdAt: now,
        updatedAt: now,
        wordCount: 0,
      );
      await docRef.set(topic.toMap());
      return topic;
    } on FirebaseException catch (e) {
      throw UserTopicServiceException('Firebase error: ${e.code}.');
    } on UserTopicServiceException {
      rethrow;
    } catch (_) {
      throw UserTopicServiceException('Không thể tạo chủ đề.');
    }
  }

  /// Deletes a topic AND all words nested under it.
  Future<void> deleteTopic(String topicId) async {
    try {
      final userId = _currentUserId;
      // Delete all words under this topic first.
      final wordsSnap = await _wordsCol(userId, topicId).get();
      final batch = _firestore.batch();
      for (final doc in wordsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_topicsCol(userId).doc(topicId));
      await batch.commit();
    } on FirebaseException catch (e) {
      throw UserTopicServiceException('Firebase error: ${e.code}.');
    } on UserTopicServiceException {
      rethrow;
    } catch (_) {
      throw UserTopicServiceException('Không thể xóa chủ đề.');
    }
  }

  // ─── Words CRUD ───────────────────────────────────────────────────

  /// Saves a vocabulary word into a topic.
  Future<TopicWordModel> addWordToTopic({
    required String topicId,
    required String word,
    required String phonetic,
    required String partOfSpeech,
    required String definition,
    required String example,
  }) async {
    try {
      final userId = _currentUserId;

      // Check for duplicate
      final existing = await _wordsCol(userId, topicId)
          .where('word', isEqualTo: word.trim())
          .where('partOfSpeech', isEqualTo: partOfSpeech.trim())
          .where('definition', isEqualTo: definition.trim())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return TopicWordModel.fromMap(existing.docs.first.data());
      }

      final docRef = _wordsCol(userId, topicId).doc();
      final now = DateTime.now();
      final topicWord = TopicWordModel(
        id: docRef.id,
        word: word.trim(),
        phonetic: phonetic.trim(),
        partOfSpeech: partOfSpeech.trim(),
        definition: definition.trim(),
        example: example.trim(),
        createdAt: now,
      );
      await docRef.set(topicWord.toMap());

      // Update word count on the topic document.
      await _topicsCol(userId).doc(topicId).update({
        'wordCount': FieldValue.increment(1),
        'updatedAt': now.toIso8601String(),
      });

      return topicWord;
    } on FirebaseException catch (e) {
      throw UserTopicServiceException('Firebase error: ${e.code}.');
    } on UserTopicServiceException {
      rethrow;
    } catch (_) {
      throw UserTopicServiceException('Không thể lưu từ vựng vào chủ đề.');
    }
  }

  /// Gets all words stored under a specific topic.
  Future<List<TopicWordModel>> getWordsForTopic(String topicId) async {
    try {
      final userId = _currentUserId;
      final snapshot = await _wordsCol(
        userId,
        topicId,
      ).orderBy('createdAt', descending: true).get();
      return snapshot.docs
          .map((doc) => TopicWordModel.fromMap(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      throw UserTopicServiceException('Firebase error: ${e.code}.');
    } on UserTopicServiceException {
      rethrow;
    } catch (_) {
      throw UserTopicServiceException('Không thể tải từ vựng của chủ đề.');
    }
  }

  /// Updates fields of an existing word in a topic.
  Future<TopicWordModel> updateWordInTopic({
    required String topicId,
    required String wordId,
    required String word,
    required String phonetic,
    required String partOfSpeech,
    required String definition,
    required String example,
  }) async {
    try {
      final userId = _currentUserId;
      final ref = _wordsCol(userId, topicId).doc(wordId);
      final updated = {
        'word': word.trim(),
        'phonetic': phonetic.trim(),
        'partOfSpeech': partOfSpeech.trim(),
        'definition': definition.trim(),
        'example': example.trim(),
      };
      await ref.update(updated);
      final snap = await ref.get();
      if (!snap.exists) {
        throw UserTopicServiceException('Không tìm thấy từ vựng sau khi cập nhật.');
      }
      return TopicWordModel.fromMap(snap.data()!);
    } on FirebaseException catch (e) {
      throw UserTopicServiceException('Firebase error: ${e.code}.');
    } on UserTopicServiceException {
      rethrow;
    } catch (_) {
      throw UserTopicServiceException('Không thể cập nhật từ vựng.');
    }
  }

  /// Deletes a single word from a topic.
  Future<void> deleteWordFromTopic({
    required String topicId,
    required String wordId,
  }) async {
    try {
      final userId = _currentUserId;
      await _wordsCol(userId, topicId).doc(wordId).delete();

      // Decrement word count.
      await _topicsCol(userId).doc(topicId).update({
        'wordCount': FieldValue.increment(-1),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } on FirebaseException catch (e) {
      throw UserTopicServiceException('Firebase error: ${e.code}.');
    } on UserTopicServiceException {
      rethrow;
    } catch (_) {
      throw UserTopicServiceException('Không thể xóa từ vựng.');
    }
  }
}
