import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../models/exercise_model.dart';
import '../models/flashcard_model.dart';
import '../models/lesson_model.dart';
import '../models/unit_model.dart';
import '../repositories/learning_repository.dart';

class LearningContentPayload {
  const LearningContentPayload({
    required this.units,
    required this.lessons,
    required this.exercises,
    required this.flashcards,
    required this.flashcardsByLesson,
  });

  final List<UnitModel> units;
  final List<LessonModel> lessons;
  final List<ExerciseModel> exercises;
  final List<FlashcardModel> flashcards;
  final Map<int, List<FlashcardModel>> flashcardsByLesson;

  bool get hasLearningData =>
      units.isNotEmpty && lessons.isNotEmpty && exercises.isNotEmpty;
}

class LearningContentService {
  LearningContentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _contentCollection = 'learning_content';
  static const String _contentDocId = 'default';
  static const List<String> _assetPaths = [
    'assets/data/english_learning_all_topics.json',
    'assets/data/learning_content.json',
  ];

  final FirebaseFirestore _firestore;
  LearningContentPayload? _cachedPayload;

  Future<LearningContentPayload?> loadContent({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedPayload != null) {
      return _cachedPayload;
    }

    final remotePayload = await _loadFromFirestore();
    if (remotePayload != null) {
      _cachedPayload = remotePayload;
      return remotePayload;
    }

    final assetPayload = await _loadFromAsset();
    _cachedPayload = assetPayload;
    return assetPayload;
  }

  Future<bool> bootstrapLearningData({
    required LearningRepository repository,
  }) async {
    final payload = await loadContent();
    if (payload == null || !payload.hasLearningData) {
      return false;
    }

    await repository.upsertLearningContent(
      units: payload.units,
      lessons: payload.lessons,
      exercises: payload.exercises,
    );
    return true;
  }

  Future<List<FlashcardModel>> getFlashcards({
    int? lessonId,
    bool forceRefresh = false,
  }) async {
    final payload = await loadContent(forceRefresh: forceRefresh);
    if (payload == null) return const [];

    if (lessonId != null && lessonId > 0) {
      final byLesson = payload.flashcardsByLesson[lessonId];
      if (byLesson != null && byLesson.isNotEmpty) {
        return byLesson;
      }
    }

    return payload.flashcards;
  }

  Future<LearningContentPayload?> _loadFromFirestore() async {
    try {
      final snapshot = await _firestore
          .collection(_contentCollection)
          .doc(_contentDocId)
          .get();
      final data = snapshot.data();
      if (data == null) return null;
      return _parsePayload(data);
    } catch (_) {
      return null;
    }
  }

  Future<LearningContentPayload?> _loadFromAsset() async {
    for (final path in _assetPaths) {
      try {
        final rawJson = await rootBundle.loadString(path);
        final decoded = jsonDecode(rawJson);
        final payload = _parsePayload(decoded);
        if (payload != null) {
          return payload;
        }
      } catch (_) {
        // Try next candidate.
      }
    }
    return null;
  }

  LearningContentPayload? _parsePayload(dynamic raw) {
    if (raw is! Map) return null;
    final root = Map<String, dynamic>.from(raw);

    final topicBundles = _parseTopics(root['topics']);
    final topicUnits = topicBundles
        .map((topic) => topic.unit)
        .whereType<UnitModel>()
        .toList();
    final topicLessons = topicBundles
        .map((topic) => topic.lesson)
        .whereType<LessonModel>()
        .toList();
    final topicExercises = topicBundles
        .expand((topic) => topic.exercises)
        .toList();

    final parsedUnits = _parseUnits(root['units']);
    final parsedLessons = _parseLessons(root['lessons']);
    final units = _mergeUnits(primary: parsedUnits, secondary: topicUnits);
    final lessons = _mergeLessons(
      primary: parsedLessons,
      secondary: topicLessons,
    );

    final flashcardsByLesson = <int, List<FlashcardModel>>{};
    for (final topic in topicBundles) {
      final lessonId = topic.lesson?.id;
      if (lessonId == null || topic.flashcards.isEmpty) continue;
      flashcardsByLesson[lessonId] = topic.flashcards;
    }

    final flashcards = _parseFlashcards(root['flashcards']);
    final mergedFlashcards = flashcards.isNotEmpty
        ? flashcards
        : flashcardsByLesson.values.expand((items) => items).toList();

    final rawExercises = [
      ..._parseExercises(root['exercises']),
      ...topicExercises,
    ];
    final exercises = _ensureExercisesPerLesson(
      lessons: lessons,
      existingExercises: rawExercises,
      flashcardsByLesson: flashcardsByLesson,
    );

    return LearningContentPayload(
      units: units,
      lessons: lessons,
      exercises: exercises,
      flashcards: mergedFlashcards,
      flashcardsByLesson: flashcardsByLesson,
    );
  }

  List<ExerciseModel> _ensureExercisesPerLesson({
    required List<LessonModel> lessons,
    required List<ExerciseModel> existingExercises,
    required Map<int, List<FlashcardModel>> flashcardsByLesson,
  }) {
    if (lessons.isEmpty) return existingExercises;

    final merged = List<ExerciseModel>.from(existingExercises);
    var nextSortSeed = merged.isEmpty
        ? 1
        : (merged.map((e) => e.sortOrder).fold<int>(0, _max) + 1);

    for (final lesson in lessons) {
      final lessonId = lesson.id;
      if (lessonId == null) continue;

      final hasExercises = merged.any((item) => item.lessonId == lessonId);
      if (hasExercises) continue;

      final cards = flashcardsByLesson[lessonId] ?? const <FlashcardModel>[];
      final generated = _generateExercisesFromFlashcards(
        lessonId: lessonId,
        flashcards: cards,
        baseSortOrder: nextSortSeed,
      );
      merged.addAll(generated);
      nextSortSeed += generated.length;
    }

    return merged;
  }

  List<ExerciseModel> _generateExercisesFromFlashcards({
    required int lessonId,
    required List<FlashcardModel> flashcards,
    required int baseSortOrder,
  }) {
    if (flashcards.isEmpty) return const [];

    final first = flashcards.first;
    final second = flashcards.length > 1 ? flashcards[1] : flashcards.first;
    final sentenceWords = first.example
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    final ordered = sentenceWords.take(4).toList();
    if (ordered.length < 4) {
      while (ordered.length < 4) {
        ordered.add(first.word);
      }
    }
    final orderedAnswer = ordered.join(' ');
    final listeningQuestion = _buildListeningQuestion(
      example: first.example,
      answer: first.word,
    );

    return [
      ExerciseModel(
        lessonId: lessonId,
        type: 'multiple_choice',
        question: 'What is the meaning of "${first.word}"?',
        correctAnswer: '${first.word} - ${first.translation}',
        options: [
          '${first.word} - ${first.translation}',
          '${second.word} - ${second.translation}',
          'Wrong meaning A',
          'Wrong meaning B',
        ].join('|'),
        illustration: first.illustration,
        sortOrder: baseSortOrder,
      ),
      ExerciseModel(
        lessonId: lessonId,
        type: 'listening',
        question: listeningQuestion,
        correctAnswer: first.word.toLowerCase(),
        options: '',
        illustration: first.illustration,
        sortOrder: baseSortOrder + 1,
      ),
      ExerciseModel(
        lessonId: lessonId,
        type: 'speaking',
        question: 'Say: ${first.example}',
        correctAnswer: first.example,
        options: '',
        illustration: first.illustration,
        sortOrder: baseSortOrder + 2,
      ),
      ExerciseModel(
        lessonId: lessonId,
        type: 'matching',
        question: 'Arrange words: $orderedAnswer',
        correctAnswer: orderedAnswer,
        options: ordered.join('|'),
        illustration: '✍️',
        sortOrder: baseSortOrder + 3,
      ),
    ];
  }

  List<_TopicBundle> _parseTopics(dynamic rawList) {
    return _toMapList(rawList)
        .map((item) {
          final unitMap = _toMap(item['unit']);
          final lessonMap = _toMap(item['lesson']);
          final unit = unitMap == null ? null : _parseUnitMap(unitMap);
          final lesson = lessonMap == null ? null : _parseLessonMap(lessonMap);
          final flashcards = _parseFlashcards(item['flashcards']);
          final exercises = _parseExercises(item['exercises']);
          return _TopicBundle(
            unit: unit,
            lesson: lesson,
            flashcards: flashcards,
            exercises: exercises,
          );
        })
        .where((topic) => topic.lesson != null)
        .toList();
  }

  List<UnitModel> _parseUnits(dynamic rawList) {
    return _toMapList(rawList)
        .map((item) {
          return _parseUnitMap(item);
        })
        .whereType<UnitModel>()
        .toList();
  }

  List<LessonModel> _parseLessons(dynamic rawList) {
    return _toMapList(rawList)
        .map((item) {
          return _parseLessonMap(item);
        })
        .whereType<LessonModel>()
        .toList();
  }

  UnitModel? _parseUnitMap(Map<String, dynamic> item) {
    final id = _toInt(item['id']);
    final title = _toStringValue(item['title']);
    final sortOrder = _toInt(item['sort_order']) ?? _toInt(item['sortOrder']);
    if (id == null || title.isEmpty) return null;
    return UnitModel(id: id, title: title, sortOrder: sortOrder ?? id);
  }

  LessonModel? _parseLessonMap(Map<String, dynamic> item) {
    final id = _toInt(item['id']);
    final unitId = _toInt(item['unit_id']) ?? _toInt(item['unitId']);
    final title = _toStringValue(item['title']);
    final icon = _toStringValue(item['icon']);
    final sortOrder = _toInt(item['sort_order']) ?? _toInt(item['sortOrder']);
    final xpReward = _toInt(item['xp_reward']) ?? _toInt(item['xpReward']);
    if (id == null || unitId == null || title.isEmpty) return null;
    return LessonModel(
      id: id,
      unitId: unitId,
      title: title,
      icon: icon.isEmpty ? 'Lesson' : icon,
      sortOrder: sortOrder ?? 0,
      xpReward: xpReward ?? 50,
    );
  }

  List<ExerciseModel> _parseExercises(dynamic rawList) {
    return _toMapList(rawList)
        .map((item) {
          final id = _toInt(item['id']);
          final lessonId =
              _toInt(item['lesson_id']) ?? _toInt(item['lessonId']);
          final type = _toStringValue(item['type']);
          final question = _toStringValue(item['question']);
          final correctAnswer = _firstNonEmptyString(
            item['correct_answer'],
            item['correctAnswer'],
          );
          final sortOrder =
              _toInt(item['sort_order']) ?? _toInt(item['sortOrder']);
          final illustration = _toStringValue(item['illustration']);
          final options = _toOptionsString(item['options']);

          if (lessonId == null ||
              type.isEmpty ||
              question.isEmpty ||
              correctAnswer.isEmpty) {
            return null;
          }

          return ExerciseModel(
            id: id,
            lessonId: lessonId,
            type: type,
            question: question,
            correctAnswer: correctAnswer,
            options: options,
            illustration: illustration,
            sortOrder: sortOrder ?? 0,
          );
        })
        .whereType<ExerciseModel>()
        .toList();
  }

  List<FlashcardModel> _parseFlashcards(dynamic rawList) {
    return _toMapList(rawList)
        .map((item) {
          final word = _toStringValue(item['word']);
          final translation = _toStringValue(item['translation']);
          final phonetic = _toStringValue(item['phonetic']);
          final example = _toStringValue(item['example']);
          final illustration = _toStringValue(item['illustration']);
          if (word.isEmpty || translation.isEmpty) return null;

          return FlashcardModel(
            word: word,
            translation: translation,
            phonetic: phonetic,
            example: example,
            illustration: illustration,
            gradStart: _toColorInt(item['grad_start'], fallback: 0xFFFBEF76),
            gradEnd: _toColorInt(item['grad_end'], fallback: 0xFFFEC288),
          );
        })
        .whereType<FlashcardModel>()
        .toList();
  }

  List<Map<String, dynamic>> _toMapList(dynamic rawList) {
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic>? _toMap(dynamic rawMap) {
    if (rawMap is! Map) return null;
    return Map<String, dynamic>.from(rawMap);
  }

  List<UnitModel> _mergeUnits({
    required List<UnitModel> primary,
    required List<UnitModel> secondary,
  }) {
    final byId = <int, UnitModel>{};
    for (final unit in primary) {
      if (unit.id == null) continue;
      byId[unit.id!] = unit;
    }
    for (final unit in secondary) {
      if (unit.id == null) continue;
      byId.putIfAbsent(unit.id!, () => unit);
    }

    final merged = byId.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return merged;
  }

  List<LessonModel> _mergeLessons({
    required List<LessonModel> primary,
    required List<LessonModel> secondary,
  }) {
    final byId = <int, LessonModel>{};
    for (final lesson in primary) {
      if (lesson.id == null) continue;
      byId[lesson.id!] = lesson;
    }
    for (final lesson in secondary) {
      if (lesson.id == null) continue;
      byId.putIfAbsent(lesson.id!, () => lesson);
    }

    final merged = byId.values.toList()
      ..sort((a, b) {
        final byUnit = a.unitId.compareTo(b.unitId);
        if (byUnit != 0) return byUnit;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return merged;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String _toStringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _firstNonEmptyString(dynamic first, dynamic second) {
    final left = _toStringValue(first);
    if (left.isNotEmpty) return left;
    return _toStringValue(second);
  }

  String _toOptionsString(dynamic rawOptions) {
    if (rawOptions is List) {
      final options = rawOptions
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      return options.join('|');
    }
    return _toStringValue(rawOptions);
  }

  int _toColorInt(dynamic value, {required int fallback}) {
    if (value is int) return value;

    final raw = _toStringValue(
      value,
    ).replaceAll('#', '').replaceAll('0x', '').replaceAll('0X', '').trim();
    if (raw.isEmpty) return fallback;

    if (raw.length == 6) {
      final rgb = int.tryParse(raw, radix: 16);
      if (rgb == null) return fallback;
      return 0xFF000000 | rgb;
    }

    if (raw.length == 8) {
      final argb = int.tryParse(raw, radix: 16);
      return argb ?? fallback;
    }

    return fallback;
  }

  int _max(int left, int right) => left > right ? left : right;

  String _buildListeningQuestion({
    required String example,
    required String answer,
  }) {
    final base = example.trim();
    if (base.isEmpty) return '___';

    final key = answer.trim();
    if (key.isNotEmpty) {
      final answerRegex = RegExp(
        r'\b' + RegExp.escape(key) + r'\b',
        caseSensitive: false,
      );
      final replaced = base.replaceFirst(answerRegex, '___');
      if (replaced != base) return replaced;
    }

    return '$base ___';
  }
}

class _TopicBundle {
  const _TopicBundle({
    required this.unit,
    required this.lesson,
    required this.flashcards,
    required this.exercises,
  });

  final UnitModel? unit;
  final LessonModel? lesson;
  final List<FlashcardModel> flashcards;
  final List<ExerciseModel> exercises;
}
