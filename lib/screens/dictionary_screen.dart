import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/dictionary_word_model.dart';
import '../data/models/exercise_model.dart';
import '../data/models/flashcard_model.dart';
import '../data/models/user_topic_model.dart';
import '../data/repositories/dictionary_repository.dart';
import '../data/services/app_services.dart';
import '../data/services/tts_service.dart';
import 'exercise_screen.dart';

enum _SavedPracticeMode { flashcard, listening, speaking, recognition }

String _relativeDateLabel(DateTime createdAt) {
  final now = DateTime.now();
  final diff = now.difference(createdAt);
  if (diff.inDays >= 7) {
    final weeks = (diff.inDays / 7).floor();
    return '$weeks week${weeks > 1 ? 's' : ''} ago';
  }
  if (diff.inDays >= 1) {
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }
  if (diff.inHours >= 1) {
    return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
  }
  return 'today';
}

String _wordContentKey(DictionaryWordModel word) {
  return [
    word.word.trim().toLowerCase(),
    word.partOfSpeech.trim().toLowerCase(),
    word.definition.trim().toLowerCase(),
  ].join('|');
}

bool _isSameWordEntry(DictionaryWordModel left, DictionaryWordModel right) {
  if (left.id != null && right.id != null) {
    return left.id == right.id;
  }
  return _wordContentKey(left) == _wordContentKey(right);
}

String _wordStatusLabel(DictionaryWordModel word) {
  if (word.isSaved) {
    return 'Saved ${_relativeDateLabel(word.createdAt)}';
  }
  if (word.id != null) {
    return 'Stored locally';
  }
  return 'Search result';
}

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;

  late AnimationController _footerCtrl;
  late Animation<Offset> _footerSlide;
  late Animation<double> _footerFade;

  final TextEditingController _searchCtrl = TextEditingController();
  final DictionaryRepository _dictionaryRepository =
      AppServices.dictionaryRepository;

  Timer? _searchDebounce;
  int _searchRequestId = 0;

  String _searchQuery = '';
  String _activeTab = 'saved';
  List<DictionaryWordModel> _savedWords = [];
  List<DictionaryWordModel> _searchResults = [];
  bool _isLoadingSavedWords = true;
  bool _isSearching = false;
  String? _savedWordsError;
  String? _searchError;

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);

    _footerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _footerSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _footerCtrl, curve: Curves.easeOut));
    _footerFade = CurvedAnimation(parent: _footerCtrl, curve: Curves.easeOut);

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _footerCtrl.forward();
    });

    _searchCtrl.addListener(_handleSearchChanged);
    _loadSavedWords();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    _searchCtrl.removeListener(_handleSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedWords() async {
    setState(() {
      _isLoadingSavedWords = true;
      _savedWordsError = null;
    });

    try {
      final words = await _dictionaryRepository.getSavedWords();
      if (!mounted) return;
      setState(() {
        _savedWords = words;
        _savedWordsError = null;
      });
    } on DictionaryRepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _savedWordsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedWordsError = 'Failed to load saved words.');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSavedWords = false);
      }
    }
  }

  void _handleSearchChanged() {
    final query = _searchCtrl.text;
    final trimmedQuery = query.trim();

    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = query;
      if (trimmedQuery.isNotEmpty && _activeTab == 'saved') {
        _activeTab = 'all';
      }
    });

    if (trimmedQuery.isEmpty) {
      _searchRequestId++;
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchWords(trimmedQuery),
    );
  }

  Future<void> _searchWords(String query) async {
    final requestId = ++_searchRequestId;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final words = await _dictionaryRepository.searchWords(query);
      if (!mounted || requestId != _searchRequestId) return;
      setState(() => _searchResults = words);
    } on DictionaryRepositoryException catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = [];
        _searchError = e.message;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchResults = [];
        _searchError = 'Failed to search dictionary.';
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _toggleBookmark(DictionaryWordModel word) async {
    try {
      if (!word.isSaved) {
        // Saving: show topic dialog first and stop if user cancels.
        final didSaveToTopic = await _showSaveToTopicDialog(word);
        if (!mounted || !didSaveToTopic) return;
      }

      final updatedWord = await _dictionaryRepository.setSavedState(
        word: word,
        isSaved: !word.isSaved,
      );
      if (!mounted) return;

      final nextSavedWords = _savedWords
          .where((item) => !_isSameWordEntry(item, updatedWord))
          .toList();
      if (updatedWord.isSaved) {
        nextSavedWords.insert(0, updatedWord);
      }

      setState(() {
        _searchResults = _searchResults
            .map((item) => _isSameWordEntry(item, word) ? updatedWord : item)
            .toList();
        _savedWords = nextSavedWords;
      });
    } on DictionaryRepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFFA5C5C),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update bookmark. Please try again.'),
          backgroundColor: Color(0xFFFA5C5C),
        ),
      );
    }
  }

  Future<bool> _showSaveToTopicDialog(DictionaryWordModel word) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SaveToTopicSheet(word: word),
    );
    return result ?? false;
  }

  List<DictionaryWordModel> get _visibleWords {
    final normalizedQuery = _searchQuery.trim().toLowerCase();

    if (_activeTab == 'saved') {
      return _savedWords.where((word) {
        if (normalizedQuery.isEmpty) return true;
        return word.word.toLowerCase().contains(normalizedQuery);
      }).toList();
    }

    return _searchResults;
  }

  int get _savedCount => _savedWords.length;

  @override
  Widget build(BuildContext context) {
    final visibleWords = _visibleWords;
    final trimmedQuery = _searchQuery.trim();
    final isSavedTab = _activeTab == 'saved';

    Widget bodySliver;

    if (isSavedTab && _isLoadingSavedWords) {
      bodySliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (isSavedTab && _savedWordsError != null) {
      bodySliver = SliverFillRemaining(
        hasScrollBody: false,
        child: _DictionaryErrorState(
          message: _savedWordsError!,
          onRetry: _loadSavedWords,
        ),
      );
    } else if (!isSavedTab && _searchError != null) {
      bodySliver = SliverFillRemaining(
        hasScrollBody: false,
        child: _DictionaryErrorState(
          message: _searchError!,
          onRetry: () => _searchWords(trimmedQuery),
        ),
      );
    } else if (!isSavedTab && _isSearching && visibleWords.isEmpty) {
      bodySliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (visibleWords.isEmpty) {
      bodySliver = SliverToBoxAdapter(
        child: _buildEmptyState(
          isSavedTab: isSavedTab,
          trimmedQuery: trimmedQuery,
        ),
      );
    } else {
      bodySliver = SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _WordCard(
              word: visibleWords[index],
              index: index,
              onToggleBookmark: _toggleBookmark,
              tts: AppServices.tts,
            ),
            childCount: visibleWords.length,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: _Header(
                  savedCount: _savedCount,
                  searchCtrl: _searchCtrl,
                  searchQuery: _searchQuery,
                  activeTab: _activeTab,
                  onTabChanged: (tab) => setState(() => _activeTab = tab),
                  onClearSearch: () => _searchCtrl.clear(),
                ),
              ),
            ),
          ),
          bodySliver,
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _footerSlide,
              child: FadeTransition(
                opacity: _footerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: _SavedPracticePanel(
                    savedCount: _savedCount,
                    onFlashcard: () =>
                        _startSavedPractice(_SavedPracticeMode.flashcard),
                    onListening: () =>
                        _startSavedPractice(_SavedPracticeMode.listening),
                    onSpeaking: () =>
                        _startSavedPractice(_SavedPracticeMode.speaking),
                    onRecognition: () =>
                        _startSavedPractice(_SavedPracticeMode.recognition),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _footerSlide,
              child: FadeTransition(
                opacity: _footerFade,
                child: _StatsFooter(
                  savedCount: _savedCount,
                  onTap: () => context.push('/user-topics'),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isSavedTab,
    required String trimmedQuery,
  }) {
    if (isSavedTab) {
      if (trimmedQuery.isNotEmpty) {
        return const _EmptyState(
          title: 'No saved words found',
          subtitle: 'Try a different search term',
        );
      }

      return const _EmptyState(
        title: 'No saved words yet',
        subtitle: 'Save words from lessons or search results to see them here',
      );
    }

    if (trimmedQuery.isEmpty) {
      return const _EmptyState(
        title: 'Search a word',
        subtitle:
            'Enter an English word to look it up with Free Dictionary API',
      );
    }

    return const _EmptyState(
      title: 'No definitions found',
      subtitle: 'Try a different English word',
    );
  }

  // ── Practice all saved words ──────────────────────────────────────

  static const int _maxPracticeItems = 24;
  static const List<List<int>> _flashcardGradients = [
    [0xFFFA5C5C, 0xFFFD8A6B],
    [0xFF6366F1, 0xFF818CF8],
    [0xFF22C55E, 0xFF4ADE80],
    [0xFFF59E0B, 0xFFFBBF24],
    [0xFF06B6D4, 0xFF67E8F9],
  ];
  static const List<String> _fallbackMeaningOptions = [
    'Một tính từ mô tả trạng thái hoặc cảm xúc.',
    'Một hành động thường gặp trong giao tiếp hằng ngày.',
    'Một danh từ chỉ sự vật hoặc khái niệm quen thuộc.',
    'Một cụm từ dùng trong ví dụ tiếng Anh cơ bản.',
  ];

  List<DictionaryWordModel> get _practiceWords {
    return _savedWords
        .where((w) => w.word.trim().isNotEmpty)
        .take(_maxPracticeItems)
        .toList();
  }

  void _startSavedPractice(_SavedPracticeMode mode) {
    final words = _practiceWords;
    if (words.isEmpty) {
      _showSnack('Bạn cần lưu ít nhất 1 từ vựng để bắt đầu ôn tập.');
      return;
    }

    if (mode == _SavedPracticeMode.flashcard) {
      _startSavedFlashcard(words);
      return;
    }

    final exercises = switch (mode) {
      _SavedPracticeMode.listening => _buildSavedListening(words),
      _SavedPracticeMode.speaking => _buildSavedSpeaking(words),
      _SavedPracticeMode.recognition => _buildSavedRecognition(words),
      _ => const <ExerciseModel>[],
    };

    if (exercises.isEmpty) {
      _showSnack('Chưa đủ dữ liệu để tạo bài luyện cho chế độ này.');
      return;
    }

    AppServices.exerciseSession.load(
      0,
      exercises,
      completionRoute: '/dictionary',
      exitRoute: '/dictionary',
      shouldPersistProgress: false,
    );

    if (!mounted) return;
    final route = switch (mode) {
      _SavedPracticeMode.listening => '/exercise/listening',
      _SavedPracticeMode.speaking => '/exercise/speaking',
      _SavedPracticeMode.recognition => '/exercise/multiple-choice',
      _ => '/exercise/multiple-choice',
    };
    context.go(route);
  }

  void _startSavedFlashcard(List<DictionaryWordModel> words) {
    final cards = <FlashcardModel>[];
    for (var i = 0; i < words.length; i++) {
      final item = words[i];
      final word = item.word.trim();
      if (word.isEmpty) continue;
      final gradient = _flashcardGradients[i % _flashcardGradients.length];
      cards.add(FlashcardModel(
        word: word,
        translation: item.definition.trim().isNotEmpty
            ? item.definition.trim()
            : 'Ý nghĩa của từ "$word".',
        phonetic: item.phonetic.trim(),
        example: item.example.trim().isNotEmpty
            ? item.example.trim()
            : 'I remember the word $word.',
        illustration: _pickIllustration(item.partOfSpeech),
        gradStart: gradient[0],
        gradEnd: gradient[1],
      ));
    }
    if (cards.isEmpty) {
      _showSnack('Không thể tạo flashcard từ dữ liệu hiện tại.');
      return;
    }
    context.push(
      '/flashcard',
      extra: FlashcardLaunchConfig(
        cards: cards,
        title: 'Flashcard · Từ đã lưu',
        closeRoute: '/dictionary',
        completeRoute: '/dictionary',
      ),
    );
  }

  List<ExerciseModel> _buildSavedListening(List<DictionaryWordModel> words) {
    final exercises = <ExerciseModel>[];
    for (var i = 0; i < words.length; i++) {
      final answer = words[i].word.trim();
      if (answer.isEmpty) continue;
      final example = words[i].example.trim();
      String question;
      if (example.isNotEmpty) {
        final regex = RegExp(r'\b' + RegExp.escape(answer) + r'\b',
            caseSensitive: false);
        final replaced = example.replaceFirst(regex, '___');
        question = replaced != example ? replaced : 'I am learning ___ today.';
      } else {
        question = 'I am learning ___ today.';
      }
      final bank = _buildWordBank(answer, words);
      exercises.add(ExerciseModel(
        lessonId: 0,
        type: 'listening',
        question: question,
        correctAnswer: answer,
        options: bank.join('|'),
        illustration: '🔊',
        sortOrder: i + 1,
      ));
    }
    return exercises;
  }

  List<ExerciseModel> _buildSavedSpeaking(List<DictionaryWordModel> words) {
    final exercises = <ExerciseModel>[];
    for (var i = 0; i < words.length; i++) {
      final item = words[i];
      final sentence = item.example.trim().isNotEmpty
          ? item.example.trim()
          : (item.word.trim().isNotEmpty
              ? 'I remember the word ${item.word.trim()}.'
              : '');
      if (sentence.isEmpty) continue;
      exercises.add(ExerciseModel(
        lessonId: 0,
        type: 'speaking',
        question: 'Read this sentence out loud.',
        correctAnswer: sentence,
        options: '',
        illustration: '🎤',
        sortOrder: i + 1,
      ));
    }
    return exercises;
  }

  List<ExerciseModel> _buildSavedRecognition(List<DictionaryWordModel> words) {
    final exercises = <ExerciseModel>[];
    for (var i = 0; i < words.length; i++) {
      final word = words[i].word.trim();
      if (word.isEmpty) continue;
      final correctMeaning = words[i].definition.trim().isNotEmpty
          ? words[i].definition.trim()
          : 'Ý nghĩa của từ "$word".';
      final distractors = words
          .asMap()
          .entries
          .where((e) => e.key != i)
          .map((e) => e.value.definition.trim().isNotEmpty
              ? e.value.definition.trim()
              : 'Ý nghĩa của từ "${e.value.word.trim()}".')
          .where((v) =>
              v.isNotEmpty &&
              v.toLowerCase() != correctMeaning.toLowerCase())
          .toList();
      final options = _buildMeaningChoices(correctMeaning, distractors);
      exercises.add(ExerciseModel(
        lessonId: 0,
        type: 'multiple_choice',
        question: 'Nghĩa đúng của "$word" là gì?',
        correctAnswer: correctMeaning,
        options: options.join('|'),
        illustration: '🧠',
        sortOrder: i + 1,
      ));
    }
    return exercises;
  }

  List<String> _buildWordBank(
      String correctWord, List<DictionaryWordModel> words) {
    final options = words
        .map((w) => w.word.trim())
        .where(
            (v) => v.isNotEmpty && v.toLowerCase() != correctWord.toLowerCase())
        .toSet()
        .toList()
      ..shuffle();
    final result = <String>[correctWord, ...options.take(3)];
    const fallback = ['friend', 'school', 'happy', 'music', 'family', 'book'];
    for (final v in fallback) {
      if (result.length >= 4) break;
      if (!result.any((r) => r.toLowerCase() == v.toLowerCase())) {
        result.add(v);
      }
    }
    result.shuffle();
    return result;
  }

  List<String> _buildMeaningChoices(
      String correctMeaning, List<String> distractors) {
    final result = <String>[correctMeaning];
    final shuffled = distractors.toSet().toList()..shuffle();
    result.addAll(shuffled.take(3));
    for (final fb in _fallbackMeaningOptions) {
      if (result.length >= 4) break;
      if (!result.any((v) => v.toLowerCase() == fb.toLowerCase())) {
        result.add(fb);
      }
    }
    result.shuffle();
    return result;
  }

  String _pickIllustration(String partOfSpeech) {
    final part = partOfSpeech.trim().toLowerCase();
    if (part.contains('verb') || part.contains('động')) return '🏃';
    if (part.contains('adjective') || part.contains('tính')) return '✨';
    if (part.contains('noun') || part.contains('danh')) return '📦';
    if (part.contains('adverb') || part.contains('trạng')) return '⚡';
    return '📘';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFA5C5C),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.savedCount,
    required this.searchCtrl,
    required this.searchQuery,
    required this.activeTab,
    required this.onTabChanged,
    required this.onClearSearch,
  });

  final int savedCount;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final subtitle = activeTab == 'saved'
        ? 'Your saved vocabulary'
        : 'Search with Free Dictionary API';

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dictionary',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEC288), Color(0xFFFBEF76)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 24,
                      color: Color(0xFF8C4A13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search words...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: onClearSearch,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _Tab(
                      label: 'Saved ($savedCount)',
                      icon: activeTab == 'saved'
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      active: activeTab == 'saved',
                      onTap: () => onTabChanged('saved'),
                    ),
                    _Tab(
                      label: 'All Words',
                      active: activeTab == 'all',
                      onTap: () => onTabChanged('all'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: active
                      ? const Color(0xFF111827)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFF111827)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatefulWidget {
  const _WordCard({
    required this.word,
    required this.index,
    required this.onToggleBookmark,
    required this.tts,
  });

  final DictionaryWordModel word;
  final int index;
  final ValueChanged<DictionaryWordModel> onToggleBookmark;
  final TtsService tts;

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    final delay = Duration(milliseconds: widget.index * 60);
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final hasPhonetic = word.phonetic.isNotEmpty;
    final hasExample = word.example.isNotEmpty;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word.word,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => widget.tts.speak(word.word),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFA5C5C),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.volume_up,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasPhonetic) ...[
                      const SizedBox(height: 6),
                      Text(
                        word.phonetic,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0x33FEC288), Color(0x33FBEF76)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        word.partOfSpeech,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      word.definition,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                      ),
                    ),
                    if (hasExample) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '"${word.example}"',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _wordStatusLabel(word),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => widget.onToggleBookmark(word),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: word.isSaved
                        ? const Icon(
                            Icons.bookmark,
                            key: ValueKey('saved'),
                            size: 24,
                            color: Color(0xFFFA5C5C),
                          )
                        : const Icon(
                            Icons.bookmark_border,
                            key: ValueKey('unsaved'),
                            size: 24,
                            color: Color(0xFFD1D5DB),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Icon(
                Icons.auto_stories_rounded,
                size: 38,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DictionaryErrorState extends StatelessWidget {
  const _DictionaryErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFFA5C5C)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA5C5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsFooter extends StatelessWidget {
  const _StatsFooter({required this.savedCount, this.onTap});

  final int savedCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFA5C5C).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Saved Words',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$savedCount',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.bookmarks_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Xem chủ đề từ vựng của tôi →',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Saved-words Practice Panel ─────────────────────────────────────────

class _SavedPracticePanel extends StatelessWidget {
  const _SavedPracticePanel({
    required this.savedCount,
    required this.onFlashcard,
    required this.onListening,
    required this.onSpeaking,
    required this.onRecognition,
  });

  final int savedCount;
  final VoidCallback onFlashcard;
  final VoidCallback onListening;
  final VoidCallback onSpeaking;
  final VoidCallback onRecognition;

  @override
  Widget build(BuildContext context) {
    if (savedCount == 0) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ôn tập từ đã lưu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Luyện tập tất cả từ vựng bạn đã lưu',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _SavedPracticeButton(
                icon: Icons.style_rounded,
                title: 'Flashcard',
                color: const Color(0xFF6366F1),
                onTap: onFlashcard,
              ),
              _SavedPracticeButton(
                icon: Icons.hearing_rounded,
                title: 'Luyện nghe',
                color: const Color(0xFFF59E0B),
                onTap: onListening,
              ),
              _SavedPracticeButton(
                icon: Icons.mic_rounded,
                title: 'Luyện nói',
                color: const Color(0xFFFA5C5C),
                onTap: onSpeaking,
              ),
              _SavedPracticeButton(
                icon: Icons.psychology_alt_rounded,
                title: 'Nhận diện từ',
                color: const Color(0xFF22C55E),
                onTap: onRecognition,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedPracticeButton extends StatelessWidget {
  const _SavedPracticeButton({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveToTopicSheet extends StatefulWidget {
  const _SaveToTopicSheet({required this.word});

  final DictionaryWordModel word;

  @override
  State<_SaveToTopicSheet> createState() => _SaveToTopicSheetState();
}

class _SaveToTopicSheetState extends State<_SaveToTopicSheet> {
  List<UserTopicModel> _topics = [];
  final Set<String> _selectedTopicIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCreatingTopic = false;
  bool _isCreatingTopicSubmitting = false;
  String? _error;
  String? _actionError;
  final TextEditingController _newTopicCtrl = TextEditingController();
  late final TextEditingController _exampleCtrl;

  @override
  void initState() {
    super.initState();
    _exampleCtrl = TextEditingController(text: widget.word.example);
    _loadTopics();
  }

  @override
  void dispose() {
    _newTopicCtrl.dispose();
    _exampleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final topics = await AppServices.userTopicService.getTopics();
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleCreateTopicInput() {
    if (_isSaving || _isCreatingTopicSubmitting) return;
    setState(() {
      _isCreatingTopic = !_isCreatingTopic;
      _actionError = null;
      if (!_isCreatingTopic) {
        _newTopicCtrl.clear();
      }
    });
  }

  Future<void> _createNewTopic() async {
    if (_isCreatingTopicSubmitting || _isSaving) return;

    final name = _newTopicCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _actionError = 'Please enter a topic name.');
      return;
    }

    setState(() {
      _isCreatingTopicSubmitting = true;
      _actionError = null;
    });
    try {
      final newTopic = await AppServices.userTopicService.createTopic(name);
      if (!mounted) return;
      setState(() {
        _topics.insert(0, newTopic);
        _selectedTopicIds.add(newTopic.id);
        _isCreatingTopic = false;
        _isCreatingTopicSubmitting = false;
        _actionError = null;
        _newTopicCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreatingTopicSubmitting = false;
        _actionError = e.toString();
      });
    }
  }

  Future<void> _saveWord() async {
    if (_selectedTopicIds.isEmpty) {
      setState(() => _actionError = 'Please select at least one topic.');
      return;
    }

    setState(() {
      _isSaving = true;
      _actionError = null;
    });

    try {
      for (final topicId in _selectedTopicIds) {
        await AppServices.userTopicService.addWordToTopic(
          topicId: topicId,
          word: widget.word.word,
          phonetic: widget.word.phonetic,
          partOfSpeech: widget.word.partOfSpeech,
          definition: widget.word.definition,
          example: _exampleCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      // Return success to parent screen and let parent handle follow-up UI.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _actionError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // â”€â”€ Handle â”€â”€
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // â”€â”€ Title â”€â”€
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.bookmark_add_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lưu vào chủ đề',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        widget.word.word,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // Create new topic input
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: !_isCreatingTopic
                ? GestureDetector(
                    onTap: _toggleCreateTopicInput,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFFA5C5C),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: Color(0xFFFA5C5C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tạo chủ đề mới',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFA5C5C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _newTopicCtrl,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _createNewTopic(),
                          decoration: InputDecoration(
                            hintText: 'Nhập tên chủ đề...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isCreatingTopicSubmitting
                                    ? null
                                    : _toggleCreateTopicInput,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B7280),
                                  side: const BorderSide(
                                    color: Color(0xFFD1D5DB),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isCreatingTopicSubmitting
                                    ? null
                                    : _createNewTopic,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFA5C5C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isCreatingTopicSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Tạo'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          if (_actionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _actionError!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          // â”€â”€ Topics list â”€â”€
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFFA5C5C),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _topics.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Chưa có chủ đề nào.\nHãy tạo chủ đề mới!',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: _topics.length,
                    itemBuilder: (context, index) {
                      final topic = _topics[index];
                      final isSelected = _selectedTopicIds.contains(topic.id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTopicIds.remove(topic.id);
                            } else {
                              _selectedTopicIds.add(topic.id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFA5C5C)
                                  : const Color(0xFFE5E7EB),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        key: ValueKey('checked'),
                                        color: Color(0xFFFA5C5C),
                                        size: 22,
                                      )
                                    : const Icon(
                                        Icons.circle_outlined,
                                        key: ValueKey('unchecked'),
                                        color: Color(0xFFD1D5DB),
                                        size: 22,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      topic.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFFFA5C5C)
                                            : const Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${topic.wordCount} từ vựng',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),


          // Example field
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                TextField(
                  controller: _exampleCtrl,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: 'C\u00e2u v\u00ed d\u1ee5 (t\u00f9y ch\u1ecdn)',
                    hintText: 'V\u00ed d\u1ee5: She showed great resilience.',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFA5C5C), width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF6366F1)),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'C\u00f3 v\u00ed d\u1ee5 \u0111\u1ec3 luy\u1ec7n nghe, luy\u1ec7n n\u00f3i v\u00e0 nh\u1eadn di\u1ec7n t\u1eeb.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // â”€â”€ Save button â”€â”€
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFA5C5C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _selectedTopicIds.isEmpty
                            ? 'Chọn chủ đề để lưu'
                            : 'Lưu vào ${_selectedTopicIds.length} chủ đề',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
