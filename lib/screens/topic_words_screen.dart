import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/exercise_model.dart';
import '../data/models/flashcard_model.dart';
import '../data/models/user_topic_model.dart';
import '../data/services/app_services.dart';
import '../data/services/tts_service.dart';
import 'exercise_screen.dart';

enum _TopicPracticeMode { flashcard, listening, speaking, recognition }

class TopicWordsScreen extends StatefulWidget {
  const TopicWordsScreen({super.key, required this.topicId, this.topic});

  final String topicId;
  final UserTopicModel? topic;

  @override
  State<TopicWordsScreen> createState() => _TopicWordsScreenState();
}

class _TopicWordsScreenState extends State<TopicWordsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;

  List<TopicWordModel> _words = [];
  bool _isLoading = true;
  bool _isAddingWord = false;
  String? _error;
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

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _headerFade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _loadWords();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final words = await AppServices.userTopicService.getWordsForTopic(
        widget.topicId,
      );
      if (!mounted) return;
      setState(() {
        _words = words;
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

  Future<void> _deleteWord(TopicWordModel word) async {
    final messenger = ScaffoldMessenger.of(context); // capture before await
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa từ vựng?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text('Bạn có chắc muốn xóa từ "${word.word}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA5C5C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AppServices.userTopicService.deleteWordFromTopic(
        topicId: widget.topicId,
        wordId: word.id,
      );
      if (!mounted) return;
      _loadWords();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFFA5C5C),
        ),
      );
    }
  }

  Future<void> _showAddWordSheet() async {
    if (_isAddingWord) return;

    final messenger = ScaffoldMessenger.of(context);
    final draft = await showModalBottomSheet<_TopicWordDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddWordSheet(),
    );

    if (draft == null) return;

    setState(() => _isAddingWord = true);
    try {
      await AppServices.userTopicService.addWordToTopic(
        topicId: widget.topicId,
        word: draft.word,
        phonetic: draft.phonetic,
        partOfSpeech: draft.partOfSpeech,
        definition: draft.definition,
        example: draft.example,
      );

      if (!mounted) return;
      await _loadWords();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã thêm từ vựng vào chủ đề.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFFA5C5C),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingWord = false);
      }
    }
  }

  String get _topicRoute => '/user-topics/${widget.topicId}';

  List<TopicWordModel> get _practiceWords {
    return _words
        .where((item) => item.word.trim().isNotEmpty)
        .take(_maxPracticeItems)
        .toList();
  }

  Future<void> _startPractice(_TopicPracticeMode mode) async {
    final practiceWords = _practiceWords;
    if (practiceWords.isEmpty) {
      _showPracticeHint('Bạn cần thêm ít nhất 1 từ vựng để bắt đầu ôn tập.');
      return;
    }

    if (mode == _TopicPracticeMode.flashcard) {
      await _startFlashcardPractice(practiceWords);
      return;
    }

    final exercises = switch (mode) {
      _TopicPracticeMode.listening => _buildListeningExercises(practiceWords),
      _TopicPracticeMode.speaking => _buildSpeakingExercises(practiceWords),
      _TopicPracticeMode.recognition => _buildRecognitionExercises(
        practiceWords,
      ),
      _ => const <ExerciseModel>[],
    };

    if (exercises.isEmpty) {
      _showPracticeHint('Chưa đủ dữ liệu để tạo bài luyện cho chế độ này.');
      return;
    }

    AppServices.exerciseSession.load(
      0,
      exercises,
      completionRoute: _topicRoute,
      exitRoute: _topicRoute,
      shouldPersistProgress: false,
    );

    if (!mounted) return;
    final route = switch (mode) {
      _TopicPracticeMode.listening => '/exercise/listening',
      _TopicPracticeMode.speaking => '/exercise/speaking',
      _TopicPracticeMode.recognition => '/exercise/multiple-choice',
      _ => '/exercise/multiple-choice',
    };
    context.go(route);
  }

  Future<void> _startFlashcardPractice(List<TopicWordModel> words) async {
    final cards = _buildFlashcards(words);
    if (cards.isEmpty) {
      _showPracticeHint('Không thể tạo flashcard từ dữ liệu hiện tại.');
      return;
    }

    await context.push(
      '/flashcard',
      extra: FlashcardLaunchConfig(
        cards: cards,
        title: 'Flashcard · ${widget.topic?.name ?? 'Chủ đề'}',
        closeRoute: _topicRoute,
        completeRoute: _topicRoute,
      ),
    );
  }

  List<FlashcardModel> _buildFlashcards(List<TopicWordModel> words) {
    final cards = <FlashcardModel>[];
    for (var i = 0; i < words.length; i++) {
      final item = words[i];
      final word = item.word.trim();
      if (word.isEmpty) continue;

      final gradient = _flashcardGradients[i % _flashcardGradients.length];
      cards.add(
        FlashcardModel(
          word: word,
          translation: _resolveMeaning(item),
          phonetic: item.phonetic.trim(),
          example: _buildSpeakingSentence(item),
          illustration: _pickIllustrationForWord(item),
          gradStart: gradient[0],
          gradEnd: gradient[1],
        ),
      );
    }
    return cards;
  }

  List<ExerciseModel> _buildListeningExercises(List<TopicWordModel> words) {
    final exercises = <ExerciseModel>[];
    for (var i = 0; i < words.length; i++) {
      final item = words[i];
      final answer = item.word.trim();
      if (answer.isEmpty) continue;

      final options = _buildWordBank(answer, words);
      exercises.add(
        ExerciseModel(
          lessonId: 0,
          type: 'listening',
          question: _buildListeningTemplate(
            answer: answer,
            example: item.example.trim(),
          ),
          correctAnswer: answer,
          options: options.join('|'),
          illustration: '🔊',
          sortOrder: i + 1,
        ),
      );
    }
    return exercises;
  }

  List<ExerciseModel> _buildSpeakingExercises(List<TopicWordModel> words) {
    final exercises = <ExerciseModel>[];
    for (var i = 0; i < words.length; i++) {
      final item = words[i];
      final target = _buildSpeakingSentence(item);
      if (target.trim().isEmpty) continue;

      exercises.add(
        ExerciseModel(
          lessonId: 0,
          type: 'speaking',
          question: 'Read this sentence out loud.',
          correctAnswer: target,
          options: '',
          illustration: '🎤',
          sortOrder: i + 1,
        ),
      );
    }
    return exercises;
  }

  List<ExerciseModel> _buildRecognitionExercises(List<TopicWordModel> words) {
    final exercises = <ExerciseModel>[];
    for (var i = 0; i < words.length; i++) {
      final item = words[i];
      final word = item.word.trim();
      if (word.isEmpty) continue;

      final correctMeaning = _resolveMeaning(item);
      final distractors = words
          .asMap()
          .entries
          .where((entry) => entry.key != i)
          .map((entry) => _resolveMeaning(entry.value))
          .where(
            (value) =>
                value.trim().isNotEmpty &&
                value.trim().toLowerCase() != correctMeaning.toLowerCase(),
          )
          .toList();
      final options = _buildMeaningChoices(correctMeaning, distractors);

      exercises.add(
        ExerciseModel(
          lessonId: 0,
          type: 'multiple_choice',
          question: 'Nghĩa đúng của "$word" là gì?',
          correctAnswer: correctMeaning,
          options: options.join('|'),
          illustration: '🧠',
          sortOrder: i + 1,
        ),
      );
    }
    return exercises;
  }

  String _resolveMeaning(TopicWordModel word) {
    final definition = word.definition.trim();
    if (definition.isNotEmpty) return definition;
    return 'Ý nghĩa của từ "${word.word.trim()}".';
  }

  String _buildListeningTemplate({
    required String answer,
    required String example,
  }) {
    if (example.isNotEmpty) {
      final answerRegex = RegExp(
        r'\b' + RegExp.escape(answer) + r'\b',
        caseSensitive: false,
      );
      final replaced = example.replaceFirst(answerRegex, '___');
      if (replaced != example) return replaced;
    }
    return 'I am learning ___ today.';
  }

  String _buildSpeakingSentence(TopicWordModel word) {
    final example = word.example.trim();
    if (example.isNotEmpty) return example;
    final value = word.word.trim();
    if (value.isEmpty) return '';
    return 'I remember the word $value.';
  }

  List<String> _buildWordBank(String correctWord, List<TopicWordModel> words) {
    final options =
        words
            .map((item) => item.word.trim())
            .where(
              (value) =>
                  value.isNotEmpty &&
                  value.toLowerCase() != correctWord.toLowerCase(),
            )
            .toSet()
            .toList()
          ..shuffle();

    final result = <String>[correctWord, ...options.take(3)];
    const fallback = ['friend', 'school', 'happy', 'music', 'family', 'book'];
    for (final value in fallback) {
      if (result.length >= 4) break;
      if (!result.any((item) => item.toLowerCase() == value.toLowerCase())) {
        result.add(value);
      }
    }

    result.shuffle();
    return result;
  }

  List<String> _buildMeaningChoices(
    String correctMeaning,
    List<String> distractors,
  ) {
    final result = <String>[correctMeaning];
    final shuffledDistractors = distractors.toSet().toList()..shuffle();
    result.addAll(shuffledDistractors.take(3));

    for (final fallback in _fallbackMeaningOptions) {
      if (result.length >= 4) break;
      if (!result.any(
        (value) => value.toLowerCase() == fallback.toLowerCase(),
      )) {
        result.add(fallback);
      }
    }

    result.shuffle();
    return result;
  }

  String _pickIllustrationForWord(TopicWordModel word) {
    final part = word.partOfSpeech.trim().toLowerCase();
    if (part.contains('verb') || part.contains('động')) return '🏃';
    if (part.contains('adjective') || part.contains('tính')) return '✨';
    if (part.contains('noun') || part.contains('danh')) return '📦';
    if (part.contains('adverb') || part.contains('trạng')) return '⚡';
    return '📘';
  }

  void _showPracticeHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFA5C5C),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topicName = widget.topic?.name ?? 'Chủ đề';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Container(
                  color: Colors.white,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.go('/user-topics'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
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
                                Text(
                                  topicName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${_words.length} từ vựng',
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
                                colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.list_alt_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorWidget(message: _error!, onRetry: _loadWords),
            )
          else if (_words.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyWords(),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: _PracticePanel(
                  onFlashcard: () =>
                      _startPractice(_TopicPracticeMode.flashcard),
                  onListening: () =>
                      _startPractice(_TopicPracticeMode.listening),
                  onSpeaking: () => _startPractice(_TopicPracticeMode.speaking),
                  onRecognition: () =>
                      _startPractice(_TopicPracticeMode.recognition),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _TopicWordCard(
                    word: _words[index],
                    index: index,
                    tts: AppServices.tts,
                    onDelete: () => _deleteWord(_words[index]),
                  ),
                  childCount: _words.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAddingWord ? null : _showAddWordSheet,
        backgroundColor: const Color(0xFFFA5C5C),
        foregroundColor: Colors.white,
        icon: _isAddingWord
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: Text(_isAddingWord ? 'Đang lưu...' : 'Thêm từ'),
      ),
    );
  }
}

// ─── Word Card ──────────────────────────────────────────────────────────

class _PracticePanel extends StatelessWidget {
  const _PracticePanel({
    required this.onFlashcard,
    required this.onListening,
    required this.onSpeaking,
    required this.onRecognition,
  });

  final VoidCallback onFlashcard;
  final VoidCallback onListening;
  final VoidCallback onSpeaking;
  final VoidCallback onRecognition;

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Ôn tập chủ đề',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn chế độ bạn muốn luyện ngay',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
              _PracticeButton(
                icon: Icons.style_rounded,
                title: 'Flashcard',
                color: const Color(0xFF6366F1),
                onTap: onFlashcard,
              ),
              _PracticeButton(
                icon: Icons.hearing_rounded,
                title: 'Luyện nghe',
                color: const Color(0xFFF59E0B),
                onTap: onListening,
              ),
              _PracticeButton(
                icon: Icons.mic_rounded,
                title: 'Luyện nói',
                color: const Color(0xFFFA5C5C),
                onTap: onSpeaking,
              ),
              _PracticeButton(
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

class _PracticeButton extends StatelessWidget {
  const _PracticeButton({
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

class _TopicWordDraft {
  const _TopicWordDraft({
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
  });

  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String definition;
  final String example;
}

class _AddWordSheet extends StatefulWidget {
  const _AddWordSheet();

  @override
  State<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<_AddWordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _wordCtrl;
  late final TextEditingController _phoneticCtrl;
  late final TextEditingController _partCtrl;
  late final TextEditingController _definitionCtrl;
  late final TextEditingController _exampleCtrl;

  @override
  void initState() {
    super.initState();
    _wordCtrl = TextEditingController();
    _phoneticCtrl = TextEditingController();
    _partCtrl = TextEditingController();
    _definitionCtrl = TextEditingController();
    _exampleCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _wordCtrl.dispose();
    _phoneticCtrl.dispose();
    _partCtrl.dispose();
    _definitionCtrl.dispose();
    _exampleCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    Navigator.pop(
      context,
      _TopicWordDraft(
        word: _wordCtrl.text.trim(),
        phonetic: _phoneticCtrl.text.trim(),
        partOfSpeech: _partCtrl.text.trim().isEmpty
            ? 'Khác'
            : _partCtrl.text.trim(),
        definition: _definitionCtrl.text.trim(),
        example: _exampleCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Thêm từ vựng vào chủ đề',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nhập đủ thông tin bạn muốn lưu.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              _InputField(
                controller: _wordCtrl,
                label: 'Từ vựng *',
                hint: 'Ví dụ: resilient',
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập từ vựng.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _InputField(
                controller: _phoneticCtrl,
                label: 'Phiên âm',
                hint: 'Ví dụ: /rɪˈzɪliənt/',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              _InputField(
                controller: _partCtrl,
                label: 'Từ loại',
                hint: 'Ví dụ: adjective (để trống sẽ là "Khác")',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              _InputField(
                controller: _definitionCtrl,
                label: 'Nghĩa *',
                hint: 'Nhập nghĩa tiếng Việt hoặc tiếng Anh',
                maxLines: 2,
                textInputAction: TextInputAction.newline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập nghĩa.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _InputField(
                controller: _exampleCtrl,
                label: 'Ví dụ *',
                hint: 'Ví dụ: She is resilient after every failure.',
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập ví dụ.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFA5C5C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Lưu từ vựng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.textInputAction,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFA5C5C), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFA5C5C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFA5C5C), width: 1.2),
        ),
      ),
    );
  }
}

class _TopicWordCard extends StatefulWidget {
  const _TopicWordCard({
    required this.word,
    required this.index,
    required this.tts,
    required this.onDelete,
  });

  final TopicWordModel word;
  final int index;
  final TtsService tts;
  final VoidCallback onDelete;

  @override
  State<_TopicWordCard> createState() => _TopicWordCardState();
}

class _TopicWordCardState extends State<_TopicWordCard>
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

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
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
                          colors: [Color(0x336366F1), Color(0x33818CF8)],
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
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onDelete,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFFFA5C5C),
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

// ─── Empty State ────────────────────────────────────────────────────────

class _EmptyWords extends StatelessWidget {
  const _EmptyWords();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 40,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có từ vựng nào',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bấm "Thêm từ" để tự nhập từ mới\nhoặc lưu từ từ trang tra cứu',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error Widget ───────────────────────────────────────────────────────

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
