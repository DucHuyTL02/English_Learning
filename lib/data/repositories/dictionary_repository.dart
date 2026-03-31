import '../datasources/dictionary_local_datasource.dart';
import '../datasources/dictionary_remote_datasource.dart';
import '../models/dictionary_word_model.dart';

class DictionaryRepositoryException implements Exception {
  DictionaryRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DictionaryRepository {
  DictionaryRepository(this._localDataSource, this._remoteDataSource);

  final DictionaryLocalDataSource _localDataSource;
  final DictionaryRemoteDataSource _remoteDataSource;

  Future<List<DictionaryWordModel>> getWords() async {
    try {
      return await _localDataSource.getWords();
    } catch (_) {
      throw DictionaryRepositoryException(
        'Unable to load vocabulary from local storage.',
      );
    }
  }

  Future<List<DictionaryWordModel>> getSavedWords() async {
    try {
      return await _localDataSource.getSavedWords();
    } catch (_) {
      throw DictionaryRepositoryException('Unable to load saved vocabulary.');
    }
  }

  Future<List<DictionaryWordModel>> searchWords(String query) async {
    try {
      final remoteWords = await _remoteDataSource.searchWord(query);
      if (remoteWords.isEmpty) return const [];

      final localWords = await _localDataSource.getWords();
      final localByKey = <String, DictionaryWordModel>{
        for (final word in localWords) _contentKey(word): word,
      };

      return remoteWords.map((word) {
        final localWord = localByKey[_contentKey(word)];
        if (localWord == null) return word;

        return word.copyWith(
          id: localWord.id,
          isSaved: localWord.isSaved,
          createdAt: localWord.createdAt,
          updatedAt: localWord.updatedAt,
        );
      }).toList();
    } on DictionaryRemoteDataSourceException catch (e) {
      throw DictionaryRepositoryException(e.message);
    } catch (_) {
      throw DictionaryRepositoryException('Failed to search dictionary.');
    }
  }

  Future<int> countSavedWords() async {
    try {
      return await _localDataSource.countSavedWords();
    } catch (_) {
      throw DictionaryRepositoryException('Unable to count saved words.');
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
        throw DictionaryRepositoryException('Unable to save the word.');
      }
      return created;
    } on DictionaryRepositoryException {
      rethrow;
    } catch (_) {
      throw DictionaryRepositoryException('Failed to add a new word.');
    }
  }

  Future<DictionaryWordModel> updateWord(DictionaryWordModel word) async {
    try {
      if (word.id == null) {
        throw DictionaryRepositoryException(
          'Unable to update a word without an id.',
        );
      }

      final updated = word.copyWith(updatedAt: DateTime.now());
      await _localDataSource.updateWord(updated);
      final refreshed = await _localDataSource.getWordById(word.id!);
      if (refreshed == null) {
        throw DictionaryRepositoryException(
          'Unable to reload the updated word.',
        );
      }
      return refreshed;
    } on DictionaryRepositoryException {
      rethrow;
    } catch (_) {
      throw DictionaryRepositoryException('Failed to update the word.');
    }
  }

  Future<DictionaryWordModel> setSavedState({
    required DictionaryWordModel word,
    required bool isSaved,
  }) async {
    try {
      DictionaryWordModel? existing;

      if (word.id != null) {
        existing = await _localDataSource.getWordById(word.id!);
      }

      existing ??= await _localDataSource.findWordByContent(
        word: word.word,
        partOfSpeech: word.partOfSpeech,
        definition: word.definition,
      );

      if (existing == null) {
        if (!isSaved) {
          return word.copyWith(isSaved: false, updatedAt: DateTime.now());
        }

        return addWord(
          word: word.word,
          phonetic: word.phonetic,
          partOfSpeech: word.partOfSpeech,
          definition: word.definition,
          example: word.example,
          isSaved: true,
        );
      }

      return updateWord(
        existing.copyWith(
          word: word.word,
          phonetic: word.phonetic.isEmpty ? existing.phonetic : word.phonetic,
          partOfSpeech: word.partOfSpeech,
          definition: word.definition,
          example: word.example.isEmpty ? existing.example : word.example,
          isSaved: isSaved,
        ),
      );
    } on DictionaryRepositoryException {
      rethrow;
    } catch (_) {
      throw DictionaryRepositoryException('Unable to update bookmark status.');
    }
  }

  Future<DictionaryWordModel> toggleSaved({
    required int wordId,
    required bool isSaved,
  }) async {
    try {
      final word = await _localDataSource.getWordById(wordId);
      if (word == null) {
        throw DictionaryRepositoryException('Unable to find the word.');
      }
      return setSavedState(word: word, isSaved: isSaved);
    } on DictionaryRepositoryException {
      rethrow;
    } catch (_) {
      throw DictionaryRepositoryException('Unable to update bookmark status.');
    }
  }

  Future<void> deleteWord(int wordId) async {
    try {
      await _localDataSource.deleteWordById(wordId);
    } catch (_) {
      throw DictionaryRepositoryException('Failed to delete the word.');
    }
  }

  String _contentKey(DictionaryWordModel word) {
    return [
      word.word.trim().toLowerCase(),
      word.partOfSpeech.trim().toLowerCase(),
      word.definition.trim().toLowerCase(),
    ].join('|');
  }
}
