import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const int _version = 4;
  static const String usersTable = 'users';
  static const String dictionaryWordsTable = 'dictionary_words';
  static const String unitsTable = 'units';
  static const String lessonsTable = 'lessons';
  static const String exercisesTable = 'exercises';
  static const String userProgressTable = 'user_progress';
  static const String dailyActivityTable = 'daily_activity';

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
          await db.execute('ALTER TABLE $usersTable ADD COLUMN total_xp INTEGER NOT NULL DEFAULT 0');
          await _createV2Tables(db);
          await _seedV2Data(db);
        }
        if (oldVersion < 3) {
          // Re-seed exercises for all lessons while preserving existing progress.
          await db.delete(exercisesTable);
          await _seedV2Data(db, includeUnitsAndLessons: false);
        }
        if (oldVersion < 4) {
          await _addUserColumnIfMissing(
            db,
            columnName: 'firebase_uid',
            columnDefinition: 'TEXT',
          );
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
        avatar_emoji TEXT NOT NULL DEFAULT '👤',
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        dark_mode_enabled INTEGER NOT NULL DEFAULT 0,
        total_xp INTEGER NOT NULL DEFAULT 0,
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

    await _createV2Tables(db);
  }

  Future<void> _addUserColumnIfMissing(
    Database db, {
    required String columnName,
    required String columnDefinition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($usersTable)');
    final hasColumn = columns.any((row) => row['name'] == columnName);
    if (hasColumn) return;
    await db.execute(
      'ALTER TABLE $usersTable ADD COLUMN $columnName $columnDefinition',
    );
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

  Future<void> _seedV2Data(Database db, {bool includeUnitsAndLessons = true}) async {
    if (includeUnitsAndLessons) {
      // ── Units ──
      await db.insert(unitsTable, {'id': 1, 'title': 'Cơ Bản', 'sort_order': 1});
      await db.insert(unitsTable, {'id': 2, 'title': 'Cuộc Sống Hàng Ngày', 'sort_order': 2});
      await db.insert(unitsTable, {'id': 3, 'title': 'Giao Tiếp', 'sort_order': 3});

      // ── Lessons ──
      final lessons = <Map<String, Object?>>[
        {'id': 1, 'unit_id': 1, 'title': 'Chào Hỏi', 'icon': '👋', 'sort_order': 1, 'xp_reward': 50},
        {'id': 2, 'unit_id': 1, 'title': 'Gia Đình', 'icon': '👨‍👩‍👧', 'sort_order': 2, 'xp_reward': 50},
        {'id': 3, 'unit_id': 1, 'title': 'Đồ Ăn', 'icon': '🍕', 'sort_order': 3, 'xp_reward': 50},
        {'id': 4, 'unit_id': 1, 'title': 'Màu Sắc', 'icon': '🎨', 'sort_order': 4, 'xp_reward': 50},
        {'id': 5, 'unit_id': 1, 'title': 'Số Đếm', 'icon': '🔢', 'sort_order': 5, 'xp_reward': 50},
        {'id': 6, 'unit_id': 2, 'title': 'Thời Gian', 'icon': '⏰', 'sort_order': 1, 'xp_reward': 60},
        {'id': 7, 'unit_id': 2, 'title': 'Thời Tiết', 'icon': '🌤', 'sort_order': 2, 'xp_reward': 60},
        {'id': 8, 'unit_id': 2, 'title': 'Mua Sắm', 'icon': '🛍', 'sort_order': 3, 'xp_reward': 60},
        {'id': 9, 'unit_id': 2, 'title': 'Phương Tiện', 'icon': '🚗', 'sort_order': 4, 'xp_reward': 60},
        {'id': 10, 'unit_id': 3, 'title': 'Đặt Câu Hỏi', 'icon': '❓', 'sort_order': 1, 'xp_reward': 70},
        {'id': 11, 'unit_id': 3, 'title': 'Chỉ Đường', 'icon': '🧭', 'sort_order': 2, 'xp_reward': 70},
        {'id': 12, 'unit_id': 3, 'title': 'Gọi Điện', 'icon': '📞', 'sort_order': 3, 'xp_reward': 70},
      ];
      for (final l in lessons) {
        await db.insert(lessonsTable, l);
      }
    }

    // ── Exercises for all lessons ──
    final exercises = <Map<String, Object?>>[
      // ════════════════════════════════════════════════════════════════════
      // LESSON 1 — Chào Hỏi (Greetings)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 1, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'How do you say "Xin chào" in English?',
        'correct_answer': 'Hello',
        'options': 'Hello|Goodbye|Thank you|Sorry',
        'illustration': '👋'},
      {'lesson_id': 1, 'type': 'multiple_choice', 'sort_order': 2,
        'question': 'What does "Good morning" mean?',
        'correct_answer': 'Chào buổi sáng',
        'options': 'Chào buổi sáng|Chào buổi tối|Tạm biệt|Cảm ơn',
        'illustration': '🌅'},
      {'lesson_id': 1, 'type': 'listening', 'sort_order': 3,
        'question': 'Nice to ___ you.',
        'correct_answer': 'meet',
        'options': '', 'illustration': ''},
      {'lesson_id': 1, 'type': 'multiple_choice', 'sort_order': 4,
        'question': 'Which phrase means "Tạm biệt"?',
        'correct_answer': 'Goodbye',
        'options': 'Hello|Goodbye|Please|Thanks',
        'illustration': '👋'},
      {'lesson_id': 1, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: Hello, how are you?',
        'correct_answer': 'Hello, how are you?',
        'options': '', 'illustration': '😊'},
      {'lesson_id': 1, 'type': 'multiple_choice', 'sort_order': 6,
        'question': 'What is the correct reply to "How are you?"',
        'correct_answer': 'I am fine, thank you',
        'options': 'I am fine, thank you|Goodbye|Good night|See you',
        'illustration': '💬'},
      {'lesson_id': 1, 'type': 'listening', 'sort_order': 7,
        'question': 'Good ___, see you tomorrow.',
        'correct_answer': 'night',
        'options': '', 'illustration': ''},
      {'lesson_id': 1, 'type': 'multiple_choice', 'sort_order': 8,
        'question': '"See you later" means:',
        'correct_answer': 'Hẹn gặp lại',
        'options': 'Xin chào|Hẹn gặp lại|Cảm ơn|Xin lỗi',
        'illustration': '🤝'},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 2 — Gia Đình (Family)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 2, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'What does "Mother" mean in Vietnamese?',
        'correct_answer': 'Mẹ',
        'options': 'Bố|Mẹ|Anh trai|Chị gái',
        'illustration': '👩'},
      {'lesson_id': 2, 'type': 'multiple_choice', 'sort_order': 2,
        'question': 'How do you say "Bố" in English?',
        'correct_answer': 'Father',
        'options': 'Mother|Father|Brother|Sister',
        'illustration': '👨'},
      {'lesson_id': 2, 'type': 'listening', 'sort_order': 3,
        'question': 'She is my ___.',
        'correct_answer': 'sister',
        'options': '', 'illustration': ''},
      {'lesson_id': 2, 'type': 'multiple_choice', 'sort_order': 4,
        'question': '"Brother" means:',
        'correct_answer': 'Anh/Em trai',
        'options': 'Anh/Em trai|Chị/Em gái|Ông|Bà',
        'illustration': '👦'},
      {'lesson_id': 2, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: This is my family.',
        'correct_answer': 'This is my family',
        'options': '', 'illustration': '👨‍👩‍👧‍👦'},
      {'lesson_id': 2, 'type': 'multiple_choice', 'sort_order': 6,
        'question': 'What does "Grandmother" mean?',
        'correct_answer': 'Bà',
        'options': 'Mẹ|Bà|Chị gái|Cô',
        'illustration': '👵'},
      {'lesson_id': 2, 'type': 'multiple_choice', 'sort_order': 7,
        'question': 'How do you say "Ông" in English?',
        'correct_answer': 'Grandfather',
        'options': 'Father|Grandfather|Uncle|Brother',
        'illustration': '👴'},
      {'lesson_id': 2, 'type': 'listening', 'sort_order': 8,
        'question': 'He is my ___.',
        'correct_answer': 'brother',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 3 — Đồ Ăn (Food)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 3, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'What is "Apple" in Vietnamese?',
        'correct_answer': 'Táo',
        'options': 'Chuối|Táo|Cam|Nho',
        'illustration': '🍎'},
      {'lesson_id': 3, 'type': 'multiple_choice', 'sort_order': 2,
        'question': 'How do you say "Cơm" in English?',
        'correct_answer': 'Rice',
        'options': 'Bread|Rice|Noodle|Soup',
        'illustration': '🍚'},
      {'lesson_id': 3, 'type': 'listening', 'sort_order': 3,
        'question': 'I like to eat ___.',
        'correct_answer': 'pizza',
        'options': '', 'illustration': ''},
      {'lesson_id': 3, 'type': 'multiple_choice', 'sort_order': 4,
        'question': '"Water" means:',
        'correct_answer': 'Nước',
        'options': 'Sữa|Trà|Nước|Cà phê',
        'illustration': '💧'},
      {'lesson_id': 3, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: I am hungry.',
        'correct_answer': 'I am hungry',
        'options': '', 'illustration': '🍽️'},
      {'lesson_id': 3, 'type': 'multiple_choice', 'sort_order': 6,
        'question': 'What does "Milk" mean?',
        'correct_answer': 'Sữa',
        'options': 'Nước|Sữa|Trà|Nước ép',
        'illustration': '🥛'},
      {'lesson_id': 3, 'type': 'multiple_choice', 'sort_order': 7,
        'question': '"Bread" in Vietnamese is:',
        'correct_answer': 'Bánh mì',
        'options': 'Cơm|Phở|Bánh mì|Bún',
        'illustration': '🍞'},
      {'lesson_id': 3, 'type': 'listening', 'sort_order': 8,
        'question': 'This ___ is delicious.',
        'correct_answer': 'food',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 4 — Màu Sắc (Colors)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 4, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'What color is the sky?',
        'correct_answer': 'Blue - Xanh dương',
        'options': 'Red|Blue|Green|Yellow',
        'illustration': '☁️'},
      {'lesson_id': 4, 'type': 'multiple_choice', 'sort_order': 2,
        'question': 'What color is a banana?',
        'correct_answer': 'Yellow',
        'options': 'Red|Blue|Green|Yellow',
        'illustration': '🍌'},
      {'lesson_id': 4, 'type': 'listening', 'sort_order': 3,
        'question': 'The sky is ___.',
        'correct_answer': 'blue',
        'options': '', 'illustration': ''},
      {'lesson_id': 4, 'type': 'speaking', 'sort_order': 4,
        'question': 'Say: The apple is red.',
        'correct_answer': 'The apple is red',
        'options': '', 'illustration': '🍎'},
      {'lesson_id': 4, 'type': 'multiple_choice', 'sort_order': 5,
        'question': 'What color is grass?',
        'correct_answer': 'Green - Xanh lá',
        'options': 'Red - Đỏ|Blue - Xanh dương|Green - Xanh lá|Yellow - Vàng',
        'illustration': '🌿'},
      {'lesson_id': 4, 'type': 'multiple_choice', 'sort_order': 6,
        'question': 'What color is snow?',
        'correct_answer': 'White',
        'options': 'White|Black|Red|Blue',
        'illustration': '❄️'},
      {'lesson_id': 4, 'type': 'listening', 'sort_order': 7,
        'question': 'The sun is ___.',
        'correct_answer': 'yellow',
        'options': '', 'illustration': ''},
      {'lesson_id': 4, 'type': 'multiple_choice', 'sort_order': 8,
        'question': 'What color is an orange?',
        'correct_answer': 'Orange - Cam',
        'options': 'Orange|Purple|Pink|Brown',
        'illustration': '🍊'},
      {'lesson_id': 4, 'type': 'speaking', 'sort_order': 9,
        'question': 'Say: My favorite color is blue.',
        'correct_answer': 'My favorite color is blue',
        'options': '', 'illustration': '💙'},
      {'lesson_id': 4, 'type': 'multiple_choice', 'sort_order': 10,
        'question': 'What color is a strawberry?',
        'correct_answer': 'Red - Đỏ',
        'options': 'Red|Blue|Green|Yellow',
        'illustration': '🍓'},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 5 — Số Đếm (Numbers)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 5, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'What is "One" in Vietnamese?',
        'correct_answer': 'Một',
        'options': 'Một|Hai|Ba|Bốn',
        'illustration': '1️⃣'},
      {'lesson_id': 5, 'type': 'multiple_choice', 'sort_order': 2,
        'question': 'How do you say "Mười" in English?',
        'correct_answer': 'Ten',
        'options': 'Five|Eight|Ten|Twelve',
        'illustration': '🔢'},
      {'lesson_id': 5, 'type': 'listening', 'sort_order': 3,
        'question': 'I have ___ apples.',
        'correct_answer': 'three',
        'options': '', 'illustration': ''},
      {'lesson_id': 5, 'type': 'multiple_choice', 'sort_order': 4,
        'question': '"Seven" means:',
        'correct_answer': 'Bảy',
        'options': 'Năm|Sáu|Bảy|Tám',
        'illustration': '7️⃣'},
      {'lesson_id': 5, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: I have five books.',
        'correct_answer': 'I have five books',
        'options': '', 'illustration': '📚'},
      {'lesson_id': 5, 'type': 'multiple_choice', 'sort_order': 6,
        'question': 'What number is "Twenty"?',
        'correct_answer': '20',
        'options': '10|15|20|25',
        'illustration': '🔢'},
      {'lesson_id': 5, 'type': 'multiple_choice', 'sort_order': 7,
        'question': 'How do you write "100" in English?',
        'correct_answer': 'One hundred',
        'options': 'One thousand|One hundred|Ten|Fifty',
        'illustration': '💯'},
      {'lesson_id': 5, 'type': 'listening', 'sort_order': 8,
        'question': 'There are ___ students in the class.',
        'correct_answer': 'twenty',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 6 — Thời Gian (Time)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 6, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'How do you ask for the time in English?',
        'correct_answer': 'What time is it?',
        'options': 'What time is it?|How old are you?|Where are you?|What is this?',
        'illustration': '⏰'},
      {'lesson_id': 6, 'type': 'multiple_choice', 'sort_order': 2,
        'question': '"Monday" means:',
        'correct_answer': 'Thứ Hai',
        'options': 'Thứ Hai|Thứ Ba|Thứ Tư|Thứ Năm',
        'illustration': '📅'},
      {'lesson_id': 6, 'type': 'listening', 'sort_order': 3,
        'question': 'It is ___ o\'clock.',
        'correct_answer': 'seven',
        'options': '', 'illustration': ''},
      {'lesson_id': 6, 'type': 'multiple_choice', 'sort_order': 4,
        'question': 'How do you say "Tháng Một" in English?',
        'correct_answer': 'January',
        'options': 'January|February|March|April',
        'illustration': '📆'},
      {'lesson_id': 6, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: It is half past three.',
        'correct_answer': 'It is half past three',
        'options': '', 'illustration': '🕞'},
      {'lesson_id': 6, 'type': 'multiple_choice', 'sort_order': 6,
        'question': '"Yesterday" means:',
        'correct_answer': 'Hôm qua',
        'options': 'Hôm nay|Hôm qua|Ngày mai|Tuần sau',
        'illustration': '📅'},
      {'lesson_id': 6, 'type': 'multiple_choice', 'sort_order': 7,
        'question': 'What day comes after Friday?',
        'correct_answer': 'Saturday',
        'options': 'Thursday|Saturday|Sunday|Monday',
        'illustration': '📅'},
      {'lesson_id': 6, 'type': 'listening', 'sort_order': 8,
        'question': 'I wake up at ___ in the morning.',
        'correct_answer': 'six',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 7 — Thời Tiết (Weather)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 7, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'What does "Sunny" mean?',
        'correct_answer': 'Nắng',
        'options': 'Mưa|Nắng|Gió|Tuyết',
        'illustration': '☀️'},
      {'lesson_id': 7, 'type': 'multiple_choice', 'sort_order': 2,
        'question': 'How do you say "Mưa" in English?',
        'correct_answer': 'Rainy',
        'options': 'Sunny|Cloudy|Rainy|Windy',
        'illustration': '🌧️'},
      {'lesson_id': 7, 'type': 'listening', 'sort_order': 3,
        'question': 'It is ___ today.',
        'correct_answer': 'cloudy',
        'options': '', 'illustration': ''},
      {'lesson_id': 7, 'type': 'multiple_choice', 'sort_order': 4,
        'question': '"Snow" means:',
        'correct_answer': 'Tuyết',
        'options': 'Mưa|Nắng|Tuyết|Sương mù',
        'illustration': '❄️'},
      {'lesson_id': 7, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: The weather is very hot today.',
        'correct_answer': 'The weather is very hot today',
        'options': '', 'illustration': '🌡️'},
      {'lesson_id': 7, 'type': 'multiple_choice', 'sort_order': 6,
        'question': '"Temperature" means:',
        'correct_answer': 'Nhiệt độ',
        'options': 'Thời tiết|Nhiệt độ|Gió|Mây',
        'illustration': '🌡️'},
      {'lesson_id': 7, 'type': 'multiple_choice', 'sort_order': 7,
        'question': 'Which word describes a day with strong wind?',
        'correct_answer': 'Windy',
        'options': 'Sunny|Rainy|Windy|Foggy',
        'illustration': '💨'},
      {'lesson_id': 7, 'type': 'listening', 'sort_order': 8,
        'question': 'It will ___ tomorrow.',
        'correct_answer': 'rain',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 8 — Mua Sắm (Shopping)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 8, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'How do you ask the price?',
        'correct_answer': 'How much is this?',
        'options': 'How much is this?|What is this?|Where is this?|Who is this?',
        'illustration': '🏷️'},
      {'lesson_id': 8, 'type': 'multiple_choice', 'sort_order': 2,
        'question': '"Expensive" means:',
        'correct_answer': 'Đắt',
        'options': 'Rẻ|Đắt|Đẹp|Xấu',
        'illustration': '💰'},
      {'lesson_id': 8, 'type': 'listening', 'sort_order': 3,
        'question': 'I want to ___ this shirt.',
        'correct_answer': 'buy',
        'options': '', 'illustration': ''},
      {'lesson_id': 8, 'type': 'multiple_choice', 'sort_order': 4,
        'question': 'What does "Cheap" mean?',
        'correct_answer': 'Rẻ',
        'options': 'Đắt|Rẻ|Mới|Cũ',
        'illustration': '🤑'},
      {'lesson_id': 8, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: Can I try this on?',
        'correct_answer': 'Can I try this on?',
        'options': '', 'illustration': '👗'},
      {'lesson_id': 8, 'type': 'multiple_choice', 'sort_order': 6,
        'question': '"Size" means:',
        'correct_answer': 'Kích cỡ',
        'options': 'Màu sắc|Giá|Kích cỡ|Chất liệu',
        'illustration': '📏'},
      {'lesson_id': 8, 'type': 'multiple_choice', 'sort_order': 7,
        'question': 'How do you say "Giảm giá" in English?',
        'correct_answer': 'Discount',
        'options': 'Price|Discount|Receipt|Change',
        'illustration': '🏷️'},
      {'lesson_id': 8, 'type': 'listening', 'sort_order': 8,
        'question': 'The total is ten ___.',
        'correct_answer': 'dollars',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 9 — Phương Tiện (Transportation)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 9, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'What does "Car" mean?',
        'correct_answer': 'Ô tô',
        'options': 'Xe đạp|Ô tô|Xe máy|Xe buýt',
        'illustration': '🚗'},
      {'lesson_id': 9, 'type': 'multiple_choice', 'sort_order': 2,
        'question': 'How do you say "Xe buýt" in English?',
        'correct_answer': 'Bus',
        'options': 'Car|Bus|Train|Plane',
        'illustration': '🚌'},
      {'lesson_id': 9, 'type': 'listening', 'sort_order': 3,
        'question': 'I go to school by ___.',
        'correct_answer': 'bus',
        'options': '', 'illustration': ''},
      {'lesson_id': 9, 'type': 'multiple_choice', 'sort_order': 4,
        'question': '"Airplane" means:',
        'correct_answer': 'Máy bay',
        'options': 'Tàu hỏa|Máy bay|Xe đạp|Thuyền',
        'illustration': '✈️'},
      {'lesson_id': 9, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: Where is the train station?',
        'correct_answer': 'Where is the train station?',
        'options': '', 'illustration': '🚂'},
      {'lesson_id': 9, 'type': 'multiple_choice', 'sort_order': 6,
        'question': '"Bicycle" means:',
        'correct_answer': 'Xe đạp',
        'options': 'Ô tô|Xe máy|Xe đạp|Xe buýt',
        'illustration': '🚲'},
      {'lesson_id': 9, 'type': 'multiple_choice', 'sort_order': 7,
        'question': 'How do you say "Tàu hỏa" in English?',
        'correct_answer': 'Train',
        'options': 'Bus|Plane|Ship|Train',
        'illustration': '🚄'},
      {'lesson_id': 9, 'type': 'listening', 'sort_order': 8,
        'question': 'The ___ is very fast.',
        'correct_answer': 'train',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 10 — Đặt Câu Hỏi (Asking Questions)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 10, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'Which word means "Ai?"',
        'correct_answer': 'Who?',
        'options': 'What?|Who?|Where?|When?',
        'illustration': '❓'},
      {'lesson_id': 10, 'type': 'multiple_choice', 'sort_order': 2,
        'question': '"Where" means:',
        'correct_answer': 'Ở đâu?',
        'options': 'Khi nào?|Ở đâu?|Tại sao?|Như thế nào?',
        'illustration': '📍'},
      {'lesson_id': 10, 'type': 'listening', 'sort_order': 3,
        'question': '___ is your name?',
        'correct_answer': 'What',
        'options': '', 'illustration': ''},
      {'lesson_id': 10, 'type': 'multiple_choice', 'sort_order': 4,
        'question': 'How do you say "Tại sao?" in English?',
        'correct_answer': 'Why?',
        'options': 'Who?|What?|Why?|How?',
        'illustration': '🤔'},
      {'lesson_id': 10, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: Where do you live?',
        'correct_answer': 'Where do you live?',
        'options': '', 'illustration': '🏠'},
      {'lesson_id': 10, 'type': 'multiple_choice', 'sort_order': 6,
        'question': '"When" means:',
        'correct_answer': 'Khi nào?',
        'options': 'Ai?|Gì?|Khi nào?|Ở đâu?',
        'illustration': '⏰'},
      {'lesson_id': 10, 'type': 'multiple_choice', 'sort_order': 7,
        'question': '"How old are you?" means:',
        'correct_answer': 'Bạn bao nhiêu tuổi?',
        'options': 'Bạn tên gì?|Bạn bao nhiêu tuổi?|Bạn ở đâu?|Bạn khỏe không?',
        'illustration': '🎂'},
      {'lesson_id': 10, 'type': 'listening', 'sort_order': 8,
        'question': '___ do you go to school?',
        'correct_answer': 'How',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 11 — Chỉ Đường (Directions)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 11, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'What does "Turn left" mean?',
        'correct_answer': 'Rẽ trái',
        'options': 'Rẽ phải|Rẽ trái|Đi thẳng|Quay lại',
        'illustration': '⬅️'},
      {'lesson_id': 11, 'type': 'multiple_choice', 'sort_order': 2,
        'question': '"Go straight" means:',
        'correct_answer': 'Đi thẳng',
        'options': 'Rẽ trái|Rẽ phải|Đi thẳng|Dừng lại',
        'illustration': '⬆️'},
      {'lesson_id': 11, 'type': 'listening', 'sort_order': 3,
        'question': 'Turn ___ at the corner.',
        'correct_answer': 'right',
        'options': '', 'illustration': ''},
      {'lesson_id': 11, 'type': 'multiple_choice', 'sort_order': 4,
        'question': 'How do you ask for directions politely?',
        'correct_answer': 'Excuse me, where is...?',
        'options': 'Excuse me, where is...?|Give me directions!|I want to go!|Take me there!',
        'illustration': '🗺️'},
      {'lesson_id': 11, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: Go straight and turn left.',
        'correct_answer': 'Go straight and turn left',
        'options': '', 'illustration': '🧭'},
      {'lesson_id': 11, 'type': 'multiple_choice', 'sort_order': 6,
        'question': '"Next to" means:',
        'correct_answer': 'Bên cạnh',
        'options': 'Phía trước|Bên cạnh|Phía sau|Đối diện',
        'illustration': '📍'},
      {'lesson_id': 11, 'type': 'multiple_choice', 'sort_order': 7,
        'question': '"Opposite" means:',
        'correct_answer': 'Đối diện',
        'options': 'Bên cạnh|Phía sau|Đối diện|Phía trên',
        'illustration': '↔️'},
      {'lesson_id': 11, 'type': 'listening', 'sort_order': 8,
        'question': 'The bank is ___ the hospital.',
        'correct_answer': 'behind',
        'options': '', 'illustration': ''},

      // ════════════════════════════════════════════════════════════════════
      // LESSON 12 — Gọi Điện (Phone Calls)
      // ════════════════════════════════════════════════════════════════════
      {'lesson_id': 12, 'type': 'multiple_choice', 'sort_order': 1,
        'question': 'How do you answer a phone call?',
        'correct_answer': 'Hello?',
        'options': 'Hello?|Goodbye!|Thank you!|Sorry!',
        'illustration': '📞'},
      {'lesson_id': 12, 'type': 'multiple_choice', 'sort_order': 2,
        'question': '"May I speak to..." means:',
        'correct_answer': 'Tôi có thể nói chuyện với...',
        'options': 'Tôi có thể nói chuyện với...|Tôi muốn gặp...|Tôi muốn mua...|Tôi muốn ăn...',
        'illustration': '🗣️'},
      {'lesson_id': 12, 'type': 'listening', 'sort_order': 3,
        'question': 'Can I take a ___?',
        'correct_answer': 'message',
        'options': '', 'illustration': ''},
      {'lesson_id': 12, 'type': 'multiple_choice', 'sort_order': 4,
        'question': '"Hold on, please" means:',
        'correct_answer': 'Xin giữ máy',
        'options': 'Tạm biệt|Xin giữ máy|Gọi lại sau|Sai số',
        'illustration': '⏳'},
      {'lesson_id': 12, 'type': 'speaking', 'sort_order': 5,
        'question': 'Say: May I speak to Mr. Smith?',
        'correct_answer': 'May I speak to Mr. Smith?',
        'options': '', 'illustration': '📱'},
      {'lesson_id': 12, 'type': 'multiple_choice', 'sort_order': 6,
        'question': '"I will call back later" means:',
        'correct_answer': 'Tôi sẽ gọi lại sau',
        'options': 'Tôi sẽ gọi lại sau|Tôi gọi nhầm số|Xin chờ một chút|Ai đang gọi?',
        'illustration': '🔄'},
      {'lesson_id': 12, 'type': 'multiple_choice', 'sort_order': 7,
        'question': '"Wrong number" means:',
        'correct_answer': 'Sai số',
        'options': 'Đúng số|Sai số|Bận|Không liên lạc được',
        'illustration': '❌'},
      {'lesson_id': 12, 'type': 'listening', 'sort_order': 8,
        'question': 'I am sorry, he is not ___ right now.',
        'correct_answer': 'available',
        'options': '', 'illustration': ''},
    ];
    for (final e in exercises) {
      await db.insert(exercisesTable, e);
    }
  }
}
