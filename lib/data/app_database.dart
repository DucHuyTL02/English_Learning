import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _version = 5;
  static const String usersTable = 'users';
  static const String dictionaryWordsTable = 'dictionary_words';
  static const String unitsTable = 'units';
  static const String lessonsTable = 'lessons';
  static const String exercisesTable = 'exercises';
  static const String userProgressTable = 'user_progress';
  static const String dailyActivityTable = 'daily_activity';
  static const String speakHistoryTable = 'speak_history';
  static const String notificationsTable = 'notifications';

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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add total_xp column to existing users table
          await db.execute(
            'ALTER TABLE $usersTable ADD COLUMN total_xp INTEGER NOT NULL DEFAULT 0',
          );
          await _createV2Tables(db);
          await _seedV2Data(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE $usersTable ADD COLUMN firebase_uid TEXT',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid ON $usersTable(firebase_uid)',
          );
        }
        if (oldVersion < 4) {
          await _createSpeakHistoryTable(db);
        }
        if (oldVersion < 5) {
          await _createNotificationsTable(db);
        }
      },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $usersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_uid TEXT,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        bio TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        birth_date TEXT NOT NULL DEFAULT '',
        avatar_emoji TEXT NOT NULL DEFAULT '🙂',
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        dark_mode_enabled INTEGER NOT NULL DEFAULT 0,
        total_xp INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid ON $usersTable(firebase_uid)',
    );

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

    await _createV2Tables(db);
    await _createSpeakHistoryTable(db);
    await _createNotificationsTable(db);
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $unitsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $lessonsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT '📖',
        sort_order INTEGER NOT NULL DEFAULT 0,
        xp_reward INTEGER NOT NULL DEFAULT 50,
        FOREIGN KEY (unit_id) REFERENCES $unitsTable(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $exercisesTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        question TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        options TEXT NOT NULL DEFAULT '',
        illustration TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (lesson_id) REFERENCES $lessonsTable(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $userProgressTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        lesson_id INTEGER NOT NULL,
        score INTEGER NOT NULL DEFAULT 0,
        xp_earned INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id),
        FOREIGN KEY (lesson_id) REFERENCES $lessonsTable(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $dailyActivityTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        xp_earned INTEGER NOT NULL DEFAULT 0,
        lessons_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id),
        UNIQUE(user_id, date)
      );
    ''');
  }

  Future<void> _createSpeakHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $speakHistoryTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_word TEXT NOT NULL,
        spoken_word TEXT NOT NULL,
        score INTEGER NOT NULL DEFAULT 0,
        edit_distance INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $notificationsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        payload TEXT NOT NULL DEFAULT '',
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES $usersTable(id)
      );
    ''');
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now();

    // Demo profile for first run (authentication is handled by FirebaseAuth).
    await db.insert(usersTable, {
      'firebase_uid': null,
      'full_name': 'Sarah Chen',
      'email': 'sarah.chen@example.com',
      'password': '__firebase_auth__',
      'bio': 'Passionate English learner 📚',
      'location': 'San Francisco, CA',
      'birth_date': '1995-03-15',
      'avatar_emoji': '🙂',
      'notifications_enabled': 1,
      'sound_enabled': 1,
      'dark_mode_enabled': 0,
      'total_xp': 0,
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

    await _seedV2Data(db);
  }

  Future<void> _seedV2Data(Database db) async {
    // ── Units ──
    await db.insert(unitsTable, {'id': 1, 'title': 'Cơ Bản', 'sort_order': 1});
    await db.insert(unitsTable, {
      'id': 2,
      'title': 'Cuộc Sống Hàng Ngày',
      'sort_order': 2,
    });
    await db.insert(unitsTable, {
      'id': 3,
      'title': 'Giao Tiếp',
      'sort_order': 3,
    });

    // ── Lessons ──
    final lessons = <Map<String, Object?>>[
      {
        'id': 1,
        'unit_id': 1,
        'title': 'Chào Hỏi',
        'icon': '👋',
        'sort_order': 1,
        'xp_reward': 50,
      },
      {
        'id': 2,
        'unit_id': 1,
        'title': 'Gia Đình',
        'icon': '👨‍👩‍👧',
        'sort_order': 2,
        'xp_reward': 50,
      },
      {
        'id': 3,
        'unit_id': 1,
        'title': 'Đồ Ăn',
        'icon': '🍕',
        'sort_order': 3,
        'xp_reward': 50,
      },
      {
        'id': 4,
        'unit_id': 1,
        'title': 'Màu Sắc',
        'icon': '🎨',
        'sort_order': 4,
        'xp_reward': 50,
      },
      {
        'id': 5,
        'unit_id': 1,
        'title': 'Số Đếm',
        'icon': '🔢',
        'sort_order': 5,
        'xp_reward': 50,
      },
      {
        'id': 6,
        'unit_id': 2,
        'title': 'Thời Gian',
        'icon': '⏰',
        'sort_order': 1,
        'xp_reward': 60,
      },
      {
        'id': 7,
        'unit_id': 2,
        'title': 'Thời Tiết',
        'icon': '🌤',
        'sort_order': 2,
        'xp_reward': 60,
      },
      {
        'id': 8,
        'unit_id': 2,
        'title': 'Mua Sắm',
        'icon': '🛍',
        'sort_order': 3,
        'xp_reward': 60,
      },
      {
        'id': 9,
        'unit_id': 2,
        'title': 'Phương Tiện',
        'icon': '🚗',
        'sort_order': 4,
        'xp_reward': 60,
      },
      {
        'id': 10,
        'unit_id': 3,
        'title': 'Đặt Câu Hỏi',
        'icon': '❓',
        'sort_order': 1,
        'xp_reward': 70,
      },
      {
        'id': 11,
        'unit_id': 3,
        'title': 'Chỉ Đường',
        'icon': '🧭',
        'sort_order': 2,
        'xp_reward': 70,
      },
      {
        'id': 12,
        'unit_id': 3,
        'title': 'Gọi Điện',
        'icon': '📞',
        'sort_order': 3,
        'xp_reward': 70,
      },
    ];
    for (final l in lessons) {
      await db.insert(lessonsTable, l);
    }

    // ── Exercises for lesson 4 (Màu Sắc) ──
    final exercises = <Map<String, Object?>>[
      {
        'lesson_id': 4,
        'type': 'multiple_choice',
        'sort_order': 1,
        'question': 'What color is the sky?',
        'correct_answer': 'Blue - Xanh dương',
        'options': 'Red |Blue |Green |Yellow ',
        'illustration': '☁️',
      },
      {
        'lesson_id': 4,
        'type': 'multiple_choice',
        'sort_order': 2,
        'question': 'What color is a banana?',
        'correct_answer': 'Yellow',
        'options': 'Red | Blue |Green |Yellow ',
        'illustration': '🍌',
      },
      {
        'lesson_id': 4,
        'type': 'listening',
        'sort_order': 3,
        'question': 'The sky is ___.',
        'correct_answer': 'blue',
        'options': '',
        'illustration': '',
      },
      {
        'lesson_id': 4,
        'type': 'speaking',
        'sort_order': 4,
        'question': 'Say: The apple is red.',
        'correct_answer': 'The apple is red',
        'options': '',
        'illustration': '🍎',
      },
      {
        'lesson_id': 4,
        'type': 'multiple_choice',
        'sort_order': 5,
        'question': 'What color is grass?',
        'correct_answer': 'Green - Xanh lá',
        'options': 'Red - Đỏ|Blue - Xanh dương|Green - Xanh lá|Yellow - Vàng',
        'illustration': '🌿',
      },
      {
        'lesson_id': 4,
        'type': 'multiple_choice',
        'sort_order': 6,
        'question': 'What color is snow?',
        'correct_answer': 'White ',
        'options': 'White |Black |Red |Blue ',
        'illustration': '❄️',
      },
      {
        'lesson_id': 4,
        'type': 'listening',
        'sort_order': 7,
        'question': 'The sun is ___.',
        'correct_answer': 'yellow',
        'options': '',
        'illustration': '',
      },
      {
        'lesson_id': 4,
        'type': 'multiple_choice',
        'sort_order': 8,
        'question': 'What color is an orange?',
        'correct_answer': 'Orange - Cam',
        'options': 'Orange |Purple |Pink |Brown ',
        'illustration': '🍊',
      },
      {
        'lesson_id': 4,
        'type': 'speaking',
        'sort_order': 9,
        'question': 'Say: My favorite color is blue.',
        'correct_answer': 'My favorite color is blue',
        'options': '',
        'illustration': '💙',
      },
      {
        'lesson_id': 4,
        'type': 'multiple_choice',
        'sort_order': 10,
        'question': 'What color is a strawberry?',
        'correct_answer': 'Red - Đỏ',
        'options': 'Red |Blue |Green |Yellow ',
        'illustration': '🍓',
      },
    ];
    for (final e in exercises) {
      await db.insert(exercisesTable, e);
    }
  }
}
