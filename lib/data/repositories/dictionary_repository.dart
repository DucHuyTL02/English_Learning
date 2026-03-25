import '../datasources/dictionary_local_datasource.dart';
import '../models/dictionary_word_model.dart';

class DictionaryRepositoryException implements Exception {
  DictionaryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DictionaryRepository {
  DictionaryRepository(this._localDataSource);

  final DictionaryLocalDataSource _localDataSource;

  Future<List<DictionaryWordModel>> getWords() async {
    try {
      return await _localDataSource.getWords();
    } catch (_) {
      throw DictionaryRepositoryException(
        'Không thể tải danh sách từ vựng từ SQLite.',
      );
    }
  }

  Future<int> countSavedWords() async {
    try {
      return await _localDataSource.countSavedWords();
    } catch (_) {
      throw DictionaryRepositoryException('Không thể đếm số từ đã lưu.');
    }
  }

  Future<DictionaryWordModel> addWord({
    required String word,
    required String phonetic,
    required String partOfSpeech,
    required String definition,
    required String example,
    bool isSaved = true,
  }) async {
    try {
      final now = DateTime.now();
      final item = DictionaryWordModel(
        word: word.trim(),
        phonetic: phonetic.trim(),
        partOfSpeech: partOfSpeech.trim(),
        definition: definition.trim(),
        example: example.trim(),
        isSaved: isSaved,
        createdAt: now,
        updatedAt: now,
      );
      final id = await _localDataSource.insertWord(item);
      final created = await _localDataSource.getWordById(id);
      if (created == null) {
        throw DictionaryRepositoryException('Không thể thêm từ mới.');
      }
      return created;
    } on DictionaryRepositoryException {
      rethrow;
    } catch (_) {
      throw DictionaryRepositoryException('Thêm từ mới thất bại.');
    }
  }

  Future<DictionaryWordModel> updateWord(DictionaryWordModel word) async {
    try {
      if (word.id == null) {
        throw DictionaryRepositoryException(
          'Không tìm thấy ID của từ cần cập nhật.',
        );
      }
      final updated = word.copyWith(updatedAt: DateTime.now());
      await _localDataSource.updateWord(updated);
      final refreshed = await _localDataSource.getWordById(word.id!);
      if (refreshed == null) {
        throw DictionaryRepositoryException(
          'Không thể tải lại từ sau cập nhật.',
        );
      }
      return refreshed;
    } on DictionaryRepositoryException {
      rethrow;
    } catch (_) {
      throw DictionaryRepositoryException('Cập nhật từ thất bại.');
    }
  }

  Future<DictionaryWordModel> toggleSaved({
    required int wordId,
    required bool isSaved,
  }) async {
    try {
      final word = await _localDataSource.getWordById(wordId);
      if (word == null) {
        throw DictionaryRepositoryException(
          'Không tìm thấy từ vựng cần cập nhật.',
        );
      }
      return updateWord(word.copyWith(isSaved: isSaved));
    } on DictionaryRepositoryException {
      rethrow;
    } catch (_) {
      throw DictionaryRepositoryException(
        'Không thể cập nhật trạng thái lưu từ vựng.',
      );
    }
  }

  Future<void> deleteWord(int wordId) async {
    try {
      await _localDataSource.deleteWordById(wordId);
    } catch (_) {
      throw DictionaryRepositoryException('Xóa từ vựng thất bại.');
    }
  }
}
