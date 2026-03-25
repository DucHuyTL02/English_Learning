import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _version = 1;
  static const String usersTable = 'users';
  static const String dictionaryWordsTable = 'dictionary_words';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await DatabaseHelper.open(
      version: _version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON;'),
      onCreate: (db, _) async {
        await _createSchema(db);
        await _seedInitialData(db);
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        bio TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        birth_date TEXT NOT NULL DEFAULT '',
        avatar_emoji TEXT NOT NULL DEFAULT '👤',
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        dark_mode_enabled INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE $dictionaryWordsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        phonetic TEXT NOT NULL,
        part_of_speech TEXT NOT NULL,
        definition TEXT NOT NULL,
        example TEXT NOT NULL,
        is_saved INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now();

    // Demo account for first run (email: sarah.chen@example.com, password: 123456)
    await db.insert(usersTable, {
      'full_name': 'Sarah Chen',
      'email': 'sarah.chen@example.com',
      'password': '123456',
      'bio': 'Passionate English learner 📚',
      'location': 'San Francisco, CA',
      'birth_date': '1995-03-15',
      'avatar_emoji': '👤',
      'notifications_enabled': 1,
      'sound_enabled': 1,
      'dark_mode_enabled': 0,
      'is_active': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    final seedWords = <Map<String, Object?>>[
      {
        'word': 'Beautiful',
        'phonetic': '/ˈbjuːtɪfəl/',
        'part_of_speech': 'adjective',
        'definition': 'Pleasing the senses or mind aesthetically',
        'example': 'The flower is beautiful',
        'daysAgo': 2,
      },
      {
        'word': 'Delicious',
        'phonetic': '/dɪˈlɪʃəs/',
        'part_of_speech': 'adjective',
        'definition': 'Highly pleasant to the taste',
        'example': 'This food is delicious',
        'daysAgo': 3,
      },
      {
        'word': 'Exciting',
        'phonetic': '/ɪkˈsaɪtɪŋ/',
        'part_of_speech': 'adjective',
        'definition': 'Causing great enthusiasm and eagerness',
        'example': 'The game is exciting',
        'daysAgo': 5,
      },
      {
        'word': 'Wonderful',
        'phonetic': '/ˈwʌndərfəl/',
        'part_of_speech': 'adjective',
        'definition': 'Inspiring delight, pleasure, or admiration',
        'example': "It's a wonderful day",
        'daysAgo': 7,
      },
      {
        'word': 'Magnificent',
        'phonetic': '/mæɡˈnɪfɪsənt/',
        'part_of_speech': 'adjective',
        'definition': 'Impressively beautiful, elaborate, or extravagant',
        'example': 'The view is magnificent',
        'daysAgo': 7,
      },
    ];

    for (final word in seedWords) {
      final daysAgo = (word['daysAgo'] as int?) ?? 0;
      final createdAt = now.subtract(Duration(days: daysAgo));
      await db.insert(dictionaryWordsTable, {
        'word': word['word'],
        'phonetic': word['phonetic'],
        'part_of_speech': word['part_of_speech'],
        'definition': word['definition'],
        'example': word['example'],
        'is_saved': 1,
        'created_at': createdAt.toIso8601String(),
        'updated_at': createdAt.toIso8601String(),
      });
    }
  }
}
