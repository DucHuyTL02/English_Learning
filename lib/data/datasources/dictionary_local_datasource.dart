import '../app_database.dart';
import '../models/dictionary_word_model.dart';

class DictionaryLocalDataSource {
  DictionaryLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<List<DictionaryWordModel>> getWords() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.dictionaryWordsTable,
      orderBy: 'id ASC',
    );
    return maps.map(DictionaryWordModel.fromMap).toList();
  }

  Future<List<DictionaryWordModel>> getSavedWords() async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.dictionaryWordsTable,
      where: 'is_saved = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC, id DESC',
    );
    return maps.map(DictionaryWordModel.fromMap).toList();
  }

  Future<DictionaryWordModel?> getWordById(int id) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.dictionaryWordsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DictionaryWordModel.fromMap(maps.first);
  }

  Future<DictionaryWordModel?> findWordByContent({
    required String word,
    required String partOfSpeech,
    required String definition,
  }) async {
    final db = await _appDatabase.database;
    final maps = await db.query(
      AppDatabase.dictionaryWordsTable,
      where:
          'LOWER(word) = ? AND LOWER(part_of_speech) = ? AND LOWER(definition) = ?',
      whereArgs: [
        word.trim().toLowerCase(),
        partOfSpeech.trim().toLowerCase(),
        definition.trim().toLowerCase(),
      ],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DictionaryWordModel.fromMap(maps.first);
  }

  Future<int> insertWord(DictionaryWordModel word) async {
    final db = await _appDatabase.database;
    return db.insert(AppDatabase.dictionaryWordsTable, word.toMap());
  }

  Future<int> updateWord(DictionaryWordModel word) async {
    final db = await _appDatabase.database;
    return db.update(
      AppDatabase.dictionaryWordsTable,
      word.toMap(),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  Future<int> deleteWordById(int id) async {
    final db = await _appDatabase.database;
    return db.delete(
      AppDatabase.dictionaryWordsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countSavedWords() async {
    final db = await _appDatabase.database;
    final maps = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${AppDatabase.dictionaryWordsTable} WHERE is_saved = 1',
    );
    if (maps.isEmpty) return 0;
    final value = maps.first['count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
