import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/services/app_services.dart';

// ─── MULTIPLE CHOICE ─────────────────────────────────────────────────────────

class MultipleChoiceScreen extends StatefulWidget {
  const MultipleChoiceScreen({super.key});
  @override
  State<MultipleChoiceScreen> createState() => _MultipleChoiceScreenState();
}

class _MultipleChoiceScreenState extends State<MultipleChoiceScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedAnswer;
  bool _isChecked = false;
  bool _isCorrect = false;
  late AnimationController _resultCtrl;
  late Animation<Offset> _resultSlide;
  late Animation<double> _resultOpacity;

  // Dynamic data from session (falls back to default if no session)
  late String _question;
  late String _illustration;
  late List<_OptionData> _options;
  late int _progress;
  late int _total;

  @override
  void initState() {
    super.initState();
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut));
    _resultOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOut));

    final session = AppServices.exerciseSession;
    final ex = session.current;
    if (ex != null && ex.type == 'multiple_choice') {
      _question = ex.question;
      _illustration = ex.illustration;
      final opts = ex.optionList;
      _options = List.generate(
        opts.length,
        (i) => _OptionData(
          id: i,
          text: opts[i],
          isCorrect: opts[i] == ex.correctAnswer,
        ),
      );
      _progress = session.currentIndex + 1;
      _total = session.total;
    } else {
      _question = 'What color is the sky?';
      _illustration = '☁️';
      _options = const [
        _OptionData(id: 0, text: 'Red - Đỏ', isCorrect: false),
        _OptionData(id: 1, text: 'Blue - Xanh dương', isCorrect: true),
        _OptionData(id: 2, text: 'Green - Xanh lá', isCorrect: false),
        _OptionData(id: 3, text: 'Yellow - Vàng', isCorrect: false),
      ];
      _progress = 1;
      _total = 10;
    }
  }

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    if (_selectedAnswer == null) return;
    setState(() {
      _isCorrect = _options[_selectedAnswer!].isCorrect;
      _isChecked = true;
    });
    _resultCtrl.forward();
  }

  void _onContinue() {
    final session = AppServices.exerciseSession;
    session.recordAnswer(_isCorrect);
    final next = session.next();
    if (next == null) {
      context.go('/lesson-completed');
      return;
    }
    final route = switch (next.type) {
      'listening' => '/exercise/listening',
      'speaking' => '/exercise/speaking',
      'matching' => '/exercise/matching',
      _ => '/exercise/multiple-choice',
    };
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _ExerciseHeader(
            progress: _progress,
            total: _total,
            onClose: () => context.go('/home'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _question,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => AppServices.tts.speak(_question),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFA5C5C),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40FA5C5C),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF87CEEB), Color(0xFF5BA3D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        _illustration,
                        style: const TextStyle(fontSize: 80),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(
                    _options.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OptionButton(
                        option: _options[i],
                        isSelected: _selectedAnswer == i,
                        isChecked: _isChecked,
                        onTap: _isChecked
                            ? null
                            : () => setState(() => _selectedAnswer = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isChecked
          ? SlideTransition(
              position: _resultSlide,
              child: FadeTransition(
                opacity: _resultOpacity,
                child: _ResultPanel(
                  isCorrect: _isCorrect,
                  onContinue: _onContinue,
                ),
              ),
            )
          : _CheckBar(enabled: _selectedAnswer != null, onCheck: _checkAnswer),
    );
  }
}

class _OptionData {
  const _OptionData({
    required this.id,
    required this.text,
    required this.isCorrect,
  });
  final int id;
  final String text;
  final bool isCorrect;
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.option,
    required this.isSelected,
    required this.isChecked,
    required this.onTap,
  });
  final _OptionData option;
  final bool isSelected, isChecked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final showCorrect = isChecked && isSelected && option.isCorrect;
    final showWrong = isChecked && isSelected && !option.isCorrect;
    final borderColor = showCorrect
        ? const Color(0xFF22C55E)
        : showWrong
        ? const Color(0xFFEF4444)
        : isSelected
        ? const Color(0xFFFA5C5C)
        : const Color(0xFFE5E7EB);
    final bgColor = showCorrect
        ? const Color(0xFFF0FDF4)
        : showWrong
        ? const Color(0xFFFEF2F2)
        : isSelected
        ? const Color(0xFFFFF5F5)
        : Colors.white;
    final textColor = showCorrect
        ? const Color(0xFF16A34A)
        : showWrong
        ? const Color(0xFFDC2626)
        : isSelected
        ? const Color(0xFFFA5C5C)
        : const Color(0xFF374151);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option.text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (showCorrect)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              )
            else if (showWrong)
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckBar extends StatelessWidget {
  const _CheckBar({required this.enabled, required this.onCheck});
  final bool enabled;
  final VoidCallback onCheck;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onCheck : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled
                ? const Color(0xFFFA5C5C)
                : const Color(0xFFE5E7EB),
            foregroundColor: enabled ? Colors.white : const Color(0xFF9CA3AF),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: const StadiumBorder(),
            elevation: enabled ? 4 : 0,
          ),
          child: const Text(
            'Kiểm Tra',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.isCorrect, required this.onContinue});
  final bool isCorrect;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final panelColor = isCorrect
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFEF2F2);
    final borderColor = isCorrect
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    final headlineColor = isCorrect
        ? const Color(0xFF15803D)
        : const Color(0xFFB91C1C);
    final subColor = isCorrect
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final btnColor = isCorrect
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        border: Border(top: BorderSide(color: borderColor, width: 3)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: borderColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCorrect ? 'Hoàn hảo! 🎉' : 'Chưa đúng!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: headlineColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCorrect
                          ? 'Xuất sắc! Tiếp tục phát huy nhé!'
                          : "Đáp án đúng là 'Blue'",
                      style: TextStyle(fontSize: 13, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: const StadiumBorder(),
                elevation: 4,
              ),
              child: const Text(
                'Tiếp Theo',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LISTENING ────────────────────────────────────────────────────────────────

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});
  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveCtrl;
  bool _isPlaying = false;
  Map<int, TextEditingController> _textCtrlMap = {};
  bool _isChecked = false;
  late int _progress;
  late int _total;
  late String _fullSentence;
  late List<String> _sentence;
  late List<_BlankData> _blanks;
  late List<String> _wordBank;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    final session = AppServices.exerciseSession;
    _progress = session.total > 0 ? session.currentIndex + 1 : 5;
    _total = session.total > 0 ? session.total : 10;
    final ex = session.current;
    if (ex != null && ex.type == 'listening') {
      _fullSentence = ex.question.replaceAll('___', ex.correctAnswer);
      // Parse question to build sentence words, blanks, and word bank
      final tokens = ex.question.split(RegExp(r'\s+'));
      final words = <String>[];
      final blankEntries = <_BlankData>[];
      int blankId = 0;
      for (final token in tokens) {
        if (token.contains('___')) {
          final afterIdx = words.isEmpty ? 0 : words.length - 1;
          blankEntries.add(
            _BlankData(
              id: blankId,
              afterWordIndex: afterIdx,
              correctAnswer: ex.correctAnswer,
            ),
          );
          blankId++;
          final suffix = token.replaceAll('___', '').trim();
          if (suffix.isNotEmpty) words.add(suffix);
        } else {
          words.add(token);
        }
      }
      _sentence = words;
      _blanks = blankEntries;
      // Build word bank: correct answer + distractors
      const distractors = ['red', 'green', 'cold', 'big', 'white', 'rainy'];
      final others =
          distractors.where((d) => d != ex.correctAnswer.toLowerCase()).toList()
            ..shuffle();
      _wordBank = [ex.correctAnswer, ...others.take(3)]..shuffle();
    } else {
      _fullSentence = 'The weather is sunny today';
      _sentence = ['The', 'is', 'today'];
      _blanks = [
        _BlankData(id: 0, afterWordIndex: 0, correctAnswer: 'weather'),
        _BlankData(id: 1, afterWordIndex: 1, correctAnswer: 'sunny'),
      ];
      _wordBank = ['weather', 'sunny', 'cold', 'rainy'];
    }
    // Initialize text controllers based on number of blanks
    _textCtrlMap = {for (final b in _blanks) b.id: TextEditingController()};
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    for (final c in _textCtrlMap.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      AppServices.tts.speak(_fullSentence);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isPlaying = false);
      });
    } else {
      AppServices.tts.stop();
    }
  }

  void _onContinue() {
    final session = AppServices.exerciseSession;
    // Record whether all blanks were filled correctly
    final allCorrect = _blanks.every((b) => _isBlankCorrect(b.id));
    session.recordAnswer(allCorrect);
    final next = session.next();
    if (next == null) {
      context.go('/lesson-completed');
      return;
    }
    final route = switch (next.type) {
      'listening' => '/exercise/listening',
      'speaking' => '/exercise/speaking',
      'matching' => '/exercise/matching',
      _ => '/exercise/multiple-choice',
    };
    context.go(route);
  }

  bool get _allFilled =>
      _textCtrlMap.values.every((c) => c.text.trim().isNotEmpty);
  void _checkAnswer() {
    if (!_allFilled) return;
    setState(() => _isChecked = true);
  }

  bool _isBlankCorrect(int id) =>
      _textCtrlMap[id]!.text.trim().toLowerCase() ==
      _blanks[id].correctAnswer.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _ExerciseHeader(
            progress: _progress,
            total: _total,
            onClose: () => context.go('/home'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFD8A6B), Color(0xFFFEC288)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Nghe và điền vào chỗ trống',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFA5C5C), Color(0xFFFD8A6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40FA5C5C),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 24,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 80,
                          child: AnimatedBuilder(
                            animation: _waveCtrl,
                            builder: (context, _) => CustomPaint(
                              size: const Size(double.infinity, 80),
                              painter: _WaveformPainter(
                                animValue: _isPlaying ? _waveCtrl.value : 0.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x30000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFFFA5C5C),
                              size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isPlaying ? 'Đang phát...' : 'Nhấn để nghe',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HOÀN THÀNH CÂU',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9CA3AF),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SentenceBuilder(
                          sentence: _sentence,
                          blanks: _blanks,
                          textCtrlMap: _textCtrlMap,
                          isChecked: _isChecked,
                          isBlankCorrect: _isBlankCorrect,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Gợi ý từ (không bắt buộc)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _wordBank
                        .map(
                          (word) => GestureDetector(
                            onTap: _isChecked
                                ? null
                                : () {
                                    for (final e in _textCtrlMap.entries) {
                                      if (e.value.text.isEmpty) {
                                        setState(() => e.value.text = word);
                                        break;
                                      }
                                    }
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                word,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _isChecked
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isChecked
                ? _onContinue
                : (_allFilled ? _checkAnswer : null),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isChecked
                  ? const Color(0xFF22C55E)
                  : _allFilled
                  ? const Color(0xFFFA5C5C)
                  : const Color(0xFFE5E7EB),
              foregroundColor: _isChecked || _allFilled
                  ? Colors.white
                  : const Color(0xFF9CA3AF),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: const StadiumBorder(),
              elevation: _allFilled || _isChecked ? 4 : 0,
            ),
            child: Text(
              _isChecked ? 'Tiếp Theo' : 'Kiểm Tra',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlankData {
  const _BlankData({
    required this.id,
    required this.afterWordIndex,
    required this.correctAnswer,
  });
  final int id, afterWordIndex;
  final String correctAnswer;
}

class _SentenceBuilder extends StatelessWidget {
  const _SentenceBuilder({
    required this.sentence,
    required this.blanks,
    required this.textCtrlMap,
    required this.isChecked,
    required this.isBlankCorrect,
  });
  final List<String> sentence;
  final List<_BlankData> blanks;
  final Map<int, TextEditingController> textCtrlMap;
  final bool isChecked;
  final bool Function(int) isBlankCorrect;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    for (int i = 0; i < sentence.length; i++) {
      parts.add(
        Text(
          sentence[i],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      );
      final blank = blanks.where((b) => b.afterWordIndex == i).firstOrNull;
      if (blank != null) {
        final correct = isChecked && isBlankCorrect(blank.id);
        final wrong = isChecked && !isBlankCorrect(blank.id);
        parts.add(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: textCtrlMap[blank.id],
                  enabled: !isChecked,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: correct
                        ? const Color(0xFF16A34A)
                        : wrong
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFA5C5C),
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: correct
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        width: 2,
                      ),
                    ),
                    fillColor: correct
                        ? const Color(0xFFF0FDF4)
                        : wrong
                        ? const Color(0xFFFEF2F2)
                        : Colors.white,
                    filled: true,
                  ),
                ),
              ),
              if (wrong)
                Text(
                  blank.correctAnswer,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts,
    );
  }
}

// ─── SPEAKING ─────────────────────────────────────────────────────────────────

class _WordMatch {
  const _WordMatch({required this.target, required this.spoken, required this.isMatch});
  final String target;
  final String spoken;
  final bool isMatch;
}

class SpeakingExerciseScreen extends StatefulWidget {
  const SpeakingExerciseScreen({super.key});
  @override
  State<SpeakingExerciseScreen> createState() => _SpeakingExerciseScreenState();
}

class _SpeakingExerciseScreenState extends State<SpeakingExerciseScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false, _hasRecorded = false;
  int? _accuracy;
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _speechInitialized = false;
  String _recognizedText = '';
  String _speechMessage = '';
  String _speechError = '';
  String? _speechLocaleId;
  double _soundLevel = 0;
  bool _isFinalizing = false;
  bool _manualStopRequested = false;
  bool _didEnterListening = false;
  bool _isRestartingListen = false;
  int _autoRestartCount = 0;
  static const int _maxAutoRestarts = 4;
  static bool _forceSystemLocale = false;
  late AnimationController _pulseCtrl1, _pulseCtrl2, _waveCtrl, _resultCtrl;
  late String _targetSentence;
  late String _phonetic;
  late int _progress;
  late int _total;

  // ── Timer (giống Android RecordCompareActivity) ──
  Timer? _recordTimer;
  int _recordSeconds = 0;
  static const int _maxRecordSeconds = 10;

  // ── Edit distance chi tiết ──
  int _editDistance = 0;
  List<_WordMatch> _wordMatches = [];
  static const _baseHeights = [
    28.0,
    45.0,
    32.0,
    60.0,
    22.0,
    55.0,
    38.0,
    50.0,
    26.0,
    64.0,
    30.0,
    48.0,
    36.0,
    58.0,
    24.0,
    52.0,
    40.0,
    44.0,
    34.0,
    62.0,
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _pulseCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final session = AppServices.exerciseSession;
    final ex = session.current;
    if (ex != null && ex.type == 'speaking') {
      _targetSentence = ex.correctAnswer;
      _phonetic = '';
      _progress = session.currentIndex + 1;
      _total = session.total;
    } else {
      _targetSentence = 'The weather is sunny today';
      _phonetic = '/ðə ˈweðər ɪz ˈsʌni təˈdeɪ/';
      _progress = 6;
      _total = 10;
    }
    _initSpeech();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _speech.stop();
    _pulseCtrl1.dispose();
    _pulseCtrl2.dispose();
    _waveCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (_speechInitialized) return;
    try {
      final available = await _speech.initialize(
        debugLogging: true,
        options: [
          SpeechToText.androidNoBluetooth,
          SpeechToText.androidIntentLookup,
        ],
        onStatus: (status) {
          // Example statuses: listening, notListening, done
          if (!mounted) return;
          setState(() {
            _speechMessage = status;
            if (status == SpeechToText.listeningStatus) {
              _didEnterListening = true;
            }
          });
          if ((status == SpeechToText.notListeningStatus ||
                  status == SpeechToText.doneStatus) &&
              _isRecording &&
              !_hasRecorded) {
            if (_manualStopRequested || _hasTranscript) {
              _queueFinalizeScoring();
            } else {
              _recoverFromUnexpectedStop();
            }
          }
        },
        onError: (error) {
          // Show error details in UI + console for quick debugging.
          // error.errorMsg contains a readable message from the plugin.
          // ignore: avoid_print
          print('speech_to_text error: ${error.errorMsg}');
          if (!mounted) return;
          setState(() {
            _speechError = error.errorMsg;
            _speechMessage = 'error';
            if (_isLanguageUnavailableError(error.errorMsg)) {
              _forceSystemLocale = true;
              _speechLocaleId = null;
            }
          });
        },
      );
      final preferredLocale = available
          ? await _selectPreferredLocaleId()
          : null;
      if (!mounted) return;
      setState(() {
        _speechAvailable = available;
        _speechInitialized = true;
        _speechLocaleId = preferredLocale;
        if (!available && _speechError.isEmpty) {
          _speechError = 'speech recognition unavailable';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
        _speechInitialized = true;
        _speechError = 'initialize failed: $e';
      });
    }
  }

  Future<String?> _selectPreferredLocaleId() async {
    try {
      if (_forceSystemLocale) return null;
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;

      final systemLocale = await _speech.systemLocale();
      if (systemLocale != null && systemLocale.localeId.isNotEmpty) {
        return systemLocale.localeId;
      }

      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id == 'en_us' || id == 'en-us') return locale.localeId;
      }

      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id.startsWith('en_') || id.startsWith('en-')) {
          return locale.localeId;
        }
      }

      return locales.first.localeId;
    } catch (_) {
      return null;
    }
  }

  bool get _hasTranscript {
    return _recognizedText.trim().isNotEmpty ||
        _speech.lastRecognizedWords.trim().isNotEmpty;
  }

  bool get _hasSpeechError {
    return _speechError.trim().isNotEmpty ||
        ((_speech.lastError?.errorMsg ?? '').trim().isNotEmpty);
  }

  bool _isLanguageUnavailableError([String? value]) {
    final fallback = _speechError.isNotEmpty
        ? _speechError
        : (_speech.lastError?.errorMsg ?? '');
    final raw = (value ?? fallback).toLowerCase();
    return raw.contains('error_language_unavailable') ||
        raw.contains('error_language_not_supported');
  }

  Future<bool> _startListeningWithLocale(String? localeId) async {
    _didEnterListening = false;
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;
          if (result.recognizedWords.isNotEmpty) {
            setState(() => _recognizedText = result.recognizedWords);
          }
          if (result.finalResult) {
            _finalizeScoring();
          }
        },
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() => _soundLevel = level);
        },
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 5),
        localeId: localeId,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      final deadline = DateTime.now().add(const Duration(milliseconds: 900));
      while (DateTime.now().isBefore(deadline)) {
        if (_speech.isListening || _didEnterListening) return true;
        if (_speechMessage == 'error') break;
        await Future.delayed(const Duration(milliseconds: 90));
      }
      return _speech.isListening || _didEnterListening;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _speechMessage = 'error';
        _speechError = 'listen failed: $e';
      });
      return false;
    }
  }

  Future<void> _recoverFromUnexpectedStop() async {
    if (_isRestartingListen ||
        _manualStopRequested ||
        !_isRecording ||
        _hasRecorded) {
      return;
    }

    if (_autoRestartCount >= _maxAutoRestarts) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        if (_speechMessage.isEmpty) {
          _speechMessage = 'notListening';
        }
        if (_speechError.isEmpty) {
          _speechError =
              _speech.lastError?.errorMsg ?? 'speech stopped before capture';
        }
      });
      return;
    }

    _isRestartingListen = true;
    try {
      var nextLocale = _speechLocaleId;
      if (_isLanguageUnavailableError() && _speechLocaleId != null) {
        _forceSystemLocale = true;
        nextLocale = null;
        if (mounted) {
          setState(() {
            _speechLocaleId = null;
            _speechMessage = 'retrying-system-locale';
            _speechError = '';
            _soundLevel = 0;
          });
        }
      } else if (mounted) {
        setState(() {
          _speechMessage = 'listening-again';
          _speechError = '';
          _soundLevel = 0;
        });
      }

      _autoRestartCount++;
      final started = await _startListeningWithLocale(nextLocale);
      if (!mounted || !_isRecording || _hasRecorded) return;

      if (!started) {
        setState(() {
          _isRecording = false;
          _speechMessage = _speech.lastStatus.isEmpty
              ? 'notListening'
              : _speech.lastStatus;
          if (_speechError.isEmpty) {
            _speechError =
                _speech.lastError?.errorMsg ?? 'listen did not start';
          }
        });
      }
    } finally {
      _isRestartingListen = false;
    }
  }

  // ── Timer helpers (giống Android) ──
  void _startRecordTimer() {
    _recordTimer?.cancel();
    _recordSeconds = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }
      setState(() => _recordSeconds++);
      if (_recordSeconds >= _maxRecordSeconds) {
        timer.cancel();
        // Tự động dừng ghi âm khi hết thời gian (giống Android)
        _manualStopRequested = true;
        _speech.stop().then((_) => _queueFinalizeScoring());
      }
    });
  }

  void _stopRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  String get _timerDisplay {
    final m = (_recordSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Normalize & Tokenize ──
  String _normalizeForScoring(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  List<String> _tokenize(String input) {
    final normalized = _normalizeForScoring(input);
    if (normalized.isEmpty) return const <String>[];
    return normalized.split(' ').where((t) => t.isNotEmpty).toList();
  }

  // ── Character-level Levenshtein (giống Android levenshteinDistance) ──
  int _charLevenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final la = a.length, lb = b.length;
    final dp = List.generate(la + 1, (_) => List<int>.filled(lb + 1, 0));
    for (var i = 0; i <= la; i++) dp[i][0] = i;
    for (var j = 0; j <= lb; j++) dp[0][j] = j;
    for (var i = 1; i <= la; i++) {
      for (var j = 1; j <= lb; j++) {
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
      }
    }
    return dp[la][lb];
  }

  // ── Word-level Levenshtein (WER) ──
  int _wordLevenshteinDistance(List<String> a, List<String> b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final curr = List<int>.filled(b.length + 1, 0);
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = math.min(
          math.min(curr[j - 1] + 1, prev[j] + 1),
          prev[j - 1] + cost,
        );
      }
      prev.setAll(0, curr);
    }
    return prev[b.length];
  }

  // ── So sánh từng từ: tạo danh sách _WordMatch ──
  List<_WordMatch> _buildWordMatches(String target, String spoken) {
    final tWords = _tokenize(target);
    final sWords = _tokenize(spoken);
    final matches = <_WordMatch>[];
    for (var i = 0; i < tWords.length; i++) {
      if (i < sWords.length) {
        final match = tWords[i] == sWords[i];
        matches.add(_WordMatch(target: tWords[i], spoken: sWords[i], isMatch: match));
      } else {
        matches.add(_WordMatch(target: tWords[i], spoken: '', isMatch: false));
      }
    }
    // Từ thừa trong spoken
    for (var i = tWords.length; i < sWords.length; i++) {
      matches.add(_WordMatch(target: '', spoken: sWords[i], isMatch: false));
    }
    return matches;
  }

  // ── Hybrid Scoring (kết hợp Android char-level + word-level) ──
  int _calculateSpeakingAccuracy(String targetSentence, String spokenSentence) {
    final targetTokens = _tokenize(targetSentence);
    final spokenTokens = _tokenize(spokenSentence);
    if (targetTokens.isEmpty) return 0;

    // 1) Word-level WER score (60% trọng số)
    final wordDist = _wordLevenshteinDistance(spokenTokens, targetTokens);
    final wer = wordDist / targetTokens.length;
    final wordScore = ((1 - wer).clamp(0.0, 1.0) * 100).round();

    // 2) Character-level score (40% trọng số) — giống Android
    final targetNorm = _normalizeForScoring(targetSentence);
    final spokenNorm = _normalizeForScoring(spokenSentence);
    final charDist = _charLevenshteinDistance(targetNorm, spokenNorm);
    final maxLen = math.max(targetNorm.length, spokenNorm.length);
    final charScore = maxLen == 0
        ? (charDist == 0 ? 100 : 0)
        : math.max(0, 100 - (charDist * 100 ~/ maxLen));

    // Lưu edit distance
    _editDistance = charDist;

    // Hybrid: 60% word + 40% char
    return (0.6 * wordScore + 0.4 * charScore).round().clamp(0, 100);
  }

  void _finalizeScoring() {
    if (_hasRecorded) return;
    _stopRecordTimer();
    final spoken = _recognizedText.isNotEmpty
        ? _recognizedText
        : _speech.lastRecognizedWords;
    final acc = _calculateSpeakingAccuracy(_targetSentence, spoken);
    final wordMatches = _buildWordMatches(_targetSentence, spoken);
    final pluginError = _speech.lastError?.errorMsg;
    final pluginStatus = _speech.lastStatus;
    setState(() {
      _isRecording = false;
      _hasRecorded = true;
      _manualStopRequested = false;
      _didEnterListening = false;
      _isRestartingListen = false;
      _autoRestartCount = 0;
      _accuracy = acc;
      _recognizedText = spoken;
      _wordMatches = wordMatches;
      if (_speechMessage.isEmpty) {
        _speechMessage = pluginStatus;
      }
      if (_speechError.isEmpty &&
          pluginError != null &&
          pluginError.isNotEmpty) {
        _speechError = pluginError;
      }
    });
    _resultCtrl.forward();
    // Lưu lịch sử phát âm vào SQLite
    _saveHistory(spoken, acc);
  }

  Future<void> _queueFinalizeScoring() async {
    if (_isFinalizing || _hasRecorded) return;
    _isFinalizing = true;
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (_speech.isListening && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      if (_isLanguageUnavailableError() && !_hasTranscript) {
        setState(() {
          _isRecording = false;
          _hasRecorded = false;
          _manualStopRequested = false;
          _didEnterListening = false;
          _isRestartingListen = false;
          _autoRestartCount = 0;
          _forceSystemLocale = true;
          _speechLocaleId = null;
          _speechMessage = 'language-unavailable-switched-locale';
        });
        return;
      }
      if (!_manualStopRequested &&
          !_hasTranscript &&
          (_hasSpeechError || !_didEnterListening)) {
        setState(() {
          _isRecording = false;
          _manualStopRequested = false;
          _didEnterListening = false;
          _isRestartingListen = false;
        });
        return;
      }
      _finalizeScoring();
    } finally {
      _isFinalizing = false;
    }
  }

  Future<void> _handleMicPress() async {
    // Tap again while recording => stop and score immediately.
    if (_isRecording) {
      _manualStopRequested = true;
      try {
        await _speech.stop();
      } finally {
        await _queueFinalizeScoring();
      }
      return;
    }

    if (_hasRecorded) return;

    await _initSpeech();
    if (!_speechAvailable) {
      setState(() {
        _isRecording = false;
        _hasRecorded = true;
        _accuracy = 0;
        _recognizedText = '';
        if (_speechError.isEmpty) _speechError = 'speech not available';
      });
      _resultCtrl.forward();
      return;
    }

    await AppServices.tts.stop();
    setState(() {
      _isRecording = true;
      _hasRecorded = false;
      _manualStopRequested = false;
      _didEnterListening = false;
      _isRestartingListen = false;
      _autoRestartCount = 0;
      _accuracy = null;
      _recognizedText = '';
      _speechMessage = 'starting';
      _speechError = '';
      _soundLevel = 0;
      _recordSeconds = 0;
      _editDistance = 0;
      _wordMatches = [];
    });
    _startRecordTimer();

    var started = await _startListeningWithLocale(_speechLocaleId);
    if (!started &&
        _speechLocaleId != null &&
        _isLanguageUnavailableError(_speechError)) {
      if (!mounted) return;
      setState(() {
        _speechMessage = 'retrying-system-locale';
        _speechError = '';
        _speechLocaleId = null;
      });
      started = await _startListeningWithLocale(null);
    }

    if (mounted && _isRecording && !started) {
      setState(() {
        _isRecording = false;
        _speechMessage = _speech.lastStatus.isEmpty
            ? 'notListening'
            : _speech.lastStatus;
        if (_speechError.isEmpty) {
          _speechError = _speech.lastError?.errorMsg ?? 'listen did not start';
        }
      });
      return;
    }

    // Note: When the user taps the mic again we call stop() and score immediately.
    // If the system stops by itself due to timeout, finalResult should arrive and call _finalizeScoring().
  }

  void _handleTryAgain() {
    _stopRecordTimer();
    if (_isRecording) _speech.stop();
    setState(() {
      _isRecording = false;
      _hasRecorded = false;
      _manualStopRequested = false;
      _didEnterListening = false;
      _isRestartingListen = false;
      _autoRestartCount = 0;
      _accuracy = null;
      _recognizedText = '';
      _speechMessage = '';
      _speechError = '';
      _soundLevel = 0;
      _recordSeconds = 0;
      _editDistance = 0;
      _wordMatches = [];
    });
    _resultCtrl.reset();
  }

  // ── Lưu lịch sử phát âm (giống saveHistory Android) ──
  Future<void> _saveHistory(String spoken, int score) async {
    if (spoken.isEmpty || score < 0) return;
    try {
      final db = await AppServices.database.database;
      await db.insert('speak_history', {
        'target_word': _targetSentence,
        'spoken_word': spoken,
        'score': score,
        'edit_distance': _editDistance,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('Failed to save speak history: $e');
    }
  }

  void _onContinue() {
    final session = AppServices.exerciseSession;
    session.recordAnswer(_accuracy != null && _accuracy! >= 70);
    final next = session.next();
    if (next == null) {
      context.go('/lesson-completed');
      return;
    }
    final route = switch (next.type) {
      'listening' => '/exercise/listening',
      'speaking' => '/exercise/speaking',
      'matching' => '/exercise/matching',
      _ => '/exercise/multiple-choice',
    };
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final acc = _accuracy;
    final isExcellent = acc != null && acc >= 80;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _ExerciseHeader(
            progress: _progress,
            total: _total,
            onClose: () => context.go('/home'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  const Text(
                    'Say the following sentence',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap 1 lần: bắt đầu thu\nTap lần nữa: dừng & chấm điểm',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Sentence card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _targetSentence,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _phonetic,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9CA3AF),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => AppServices.tts.speak(_targetSentence),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFA5C5C),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x40FA5C5C),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Mic button
                  GestureDetector(
                    onTap: _isRecording
                        ? _handleMicPress
                        : (!_hasRecorded ? _handleMicPress : null),
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isRecording) ...[
                            AnimatedBuilder(
                              animation: _pulseCtrl1,
                              builder: (context, _) => Transform.scale(
                                scale: 1 + _pulseCtrl1.value * 0.36,
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFA5C5C).withValues(
                                      alpha: (1 - _pulseCtrl1.value) * 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _pulseCtrl2,
                              builder: (context, _) => Transform.scale(
                                scale: 1 + _pulseCtrl2.value * 0.46,
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFD8A6B).withValues(
                                      alpha: (1 - _pulseCtrl2.value) * 0.35,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? null
                                  : _hasRecorded
                                  ? const Color(0xFFE5E7EB)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: (!_isRecording && !_hasRecorded)
                                  ? Border.all(
                                      color: const Color(0xFFFA5C5C),
                                      width: 4,
                                    )
                                  : null,
                              gradient: _isRecording
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFA5C5C),
                                        Color(0xFFFD8A6B),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: _isRecording
                                      ? const Color(0x50FA5C5C)
                                      : const Color(0x20000000),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.mic_rounded,
                              size: 72,
                              color: _isRecording
                                  ? Colors.white
                                  : _hasRecorded
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFFFA5C5C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Timer + status text (giống Android)
                  if (_isRecording)
                    Text(
                      '$_timerDisplay / 00:${_maxRecordSeconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Color(0xFFFA5C5C),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _isRecording
                        ? 'Đang nghe... (tap để dừng)'
                        : _hasRecorded
                        ? 'Đã hoàn thành'
                        : 'Tap để nói',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _isRecording
                          ? const Color(0xFFFA5C5C)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  // Waveform
                  if (_isRecording) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 80,
                      child: AnimatedBuilder(
                        animation: _waveCtrl,
                        builder: (context, _) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(_baseHeights.length, (i) {
                              final h =
                                  (_baseHeights[i] +
                                          math.sin(
                                                _waveCtrl.value * math.pi +
                                                    i * 0.45,
                                              ) *
                                              18)
                                      .clamp(8.0, 80.0);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2.5,
                                ),
                                child: Container(
                                  width: 6,
                                  height: h,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFD8A6B),
                                        Color(0xFFFA5C5C),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                  // Accuracy card — enhanced (giống Android score screen)
                  if (acc != null) ...[
                    const SizedBox(height: 24),
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _resultCtrl,
                        curve: Curves.elasticOut,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isExcellent
                                ? [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)]
                                : acc >= 50
                                ? [const Color(0xFFFEFCE8), const Color(0xFFFEF9C3)]
                                : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isExcellent
                                ? const Color(0xFF22C55E)
                                : acc >= 50
                                ? const Color(0xFFEAB308)
                                : const Color(0xFFEF4444),
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Header row: icon + message + score
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isExcellent
                                        ? const Color(0xFF22C55E)
                                        : acc >= 50
                                        ? const Color(0xFFEAB308)
                                        : const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: isExcellent
                                      ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32)
                                      : acc >= 50
                                      ? const Center(child: Text('💪', style: TextStyle(fontSize: 26)))
                                      : const Icon(Icons.refresh_rounded, color: Colors.white, size: 32),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isExcellent
                                            ? 'Xuất sắc! 🎉'
                                            : acc >= 50
                                            ? 'Khá tốt! 👍'
                                            : 'Cần cải thiện 💪',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isExcellent
                                              ? const Color(0xFF15803D)
                                              : acc >= 50
                                              ? const Color(0xFF854D0E)
                                              : const Color(0xFF991B1B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isExcellent
                                            ? 'Phát âm rất chính xác'
                                            : acc >= 50
                                            ? 'Gần đúng, luyện thêm nhé'
                                            : 'Thử lại để cải thiện',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isExcellent
                                              ? const Color(0xFF16A34A)
                                              : acc >= 50
                                              ? const Color(0xFF92400E)
                                              : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '$acc%',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: isExcellent
                                            ? const Color(0xFF22C55E)
                                            : acc >= 50
                                            ? const Color(0xFFEAB308)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                    const Text(
                                      'Độ chính xác',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: acc / 100),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeOut,
                                builder: (context, value, _) => LinearProgressIndicator(
                                  value: value,
                                  minHeight: 12,
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isExcellent
                                        ? const Color(0xFF22C55E)
                                        : acc >= 50
                                        ? const Color(0xFFEAB308)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // So sánh từng từ (giống Android score screen)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mẫu
                                  const Text(
                                    'Câu mẫu:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _targetSentence,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Bạn nói
                                  const Text(
                                    'Bạn nói:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (_recognizedText.isEmpty)
                                    const Text(
                                      'Không nhận diện được',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: _wordMatches.map((wm) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: wm.isMatch
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: wm.isMatch
                                                  ? const Color(0xFF22C55E)
                                                  : const Color(0xFFEF4444),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            wm.spoken.isNotEmpty ? wm.spoken : '___',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: wm.isMatch
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 10),
                                  // Edit distance
                                  Text(
                                    'Khoảng cách chỉnh sửa: $_editDistance',
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
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: acc != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFA5C5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: const StadiumBorder(),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!isExcellent) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _handleTryAgain,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 2,
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  !_speechAvailable
                      ? 'Chưa sẵn sàng nhận diện giọng nói (kiểm tra quyền mic)'
                      : _isRecording
                      ? 'Đang nghe...'
                      : _hasRecorded
                      ? 'Đang chấm điểm...'
                      : 'Chạm mic để bắt đầu',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── MATCHING (WORD ORDER) ────────────────────────────────────────────────────

class _WordItem {
  _WordItem({required this.id, required this.text});
  final int id;
  final String text;
}

class MatchingExerciseScreen extends StatefulWidget {
  const MatchingExerciseScreen({super.key});
  @override
  State<MatchingExerciseScreen> createState() => _MatchingExerciseScreenState();
}

class _MatchingExerciseScreenState extends State<MatchingExerciseScreen>
    with SingleTickerProviderStateMixin {
  static const _correctOrder = ['I', 'love', 'learning', 'English'];
  late List<_WordItem> _available;
  final List<_WordItem> _ordered = [];
  bool _isChecked = false;
  late AnimationController _resultCtrl;
  late int _progress;
  late int _total;

  @override
  void initState() {
    super.initState();
    _available = [
      _WordItem(id: 0, text: 'English'),
      _WordItem(id: 1, text: 'love'),
      _WordItem(id: 2, text: 'I'),
      _WordItem(id: 3, text: 'learning'),
    ];
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final session = AppServices.exerciseSession;
    _progress = session.total > 0 ? session.currentIndex + 1 : 7;
    _total = session.total > 0 ? session.total : 10;
  }

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  bool get _isCorrect =>
      _ordered.map((w) => w.text).join(' ') == _correctOrder.join(' ');
  bool get _canCheck => _ordered.length == _correctOrder.length;

  void _add(_WordItem w) {
    if (_isChecked) return;
    setState(() {
      _available.removeWhere((x) => x.id == w.id);
      _ordered.add(w);
    });
  }

  void _remove(_WordItem w) {
    if (_isChecked) return;
    setState(() {
      _ordered.removeWhere((x) => x.id == w.id);
      _available.add(w);
    });
  }

  void _check() {
    setState(() => _isChecked = true);
    _resultCtrl.forward();
  }

  void _reset() {
    setState(() {
      _available.addAll(_ordered);
      _ordered.clear();
      _isChecked = false;
    });
    _resultCtrl.reset();
  }

  void _onContinue() {
    final session = AppServices.exerciseSession;
    session.recordAnswer(_isCorrect);
    final next = session.next();
    if (next == null) {
      context.go('/lesson-completed');
      return;
    }
    final route = switch (next.type) {
      'listening' => '/exercise/listening',
      'speaking' => '/exercise/speaking',
      'matching' => '/exercise/matching',
      _ => '/exercise/multiple-choice',
    };
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final ok = _isCorrect;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _ExerciseHeader(
            progress: _progress,
            total: _total,
            onClose: () => context.go('/home'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Text('🔤', style: TextStyle(fontSize: 30)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Put the words in the correct order',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 40),
                    child: Text(
                      'Tap words to build the sentence',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your answer:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DragTarget<_WordItem>(
                    onAcceptWithDetails: (d) => _add(d.data),
                    builder: (context, cand, _) {
                      final hl = cand.isNotEmpty;
                      final bc = _isChecked
                          ? (ok
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444))
                          : hl
                          ? const Color(0xFFFA5C5C)
                          : const Color(0xFFD1D5DB);
                      final bg = _isChecked
                          ? (ok
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFEF2F2))
                          : hl
                          ? const Color(0xFFFFF5F5)
                          : Colors.white;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 100),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: bc, width: 2),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: _ordered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '👆',
                                        style: TextStyle(fontSize: 32),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Tap or drag words here',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _ordered.asMap().entries.map((e) {
                                  final wBg = _isChecked
                                      ? (ok
                                            ? const Color(0xFFBBF7D0)
                                            : const Color(0xFFFECACA))
                                      : const Color(0xFFFA5C5C);
                                  final wFg = _isChecked
                                      ? (ok
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFDC2626))
                                      : Colors.white;
                                  return GestureDetector(
                                    onTap: () => _remove(e.value),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: wBg,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${e.key + 1} ',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: wFg.withValues(alpha: 0.6),
                                            ),
                                          ),
                                          Text(
                                            e.value.text,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: wFg,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      );
                    },
                  ),
                  if (_isChecked) ...[
                    const SizedBox(height: 12),
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _resultCtrl,
                        curve: Curves.elasticOut,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            ok
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            color: ok
                                ? const Color(0xFF22C55E)
                                : const Color(0xFFEF4444),
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ok ? 'Perfect!' : 'Not quite right',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ok
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_isChecked && !ok) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFBBF7D0),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Correct order:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _correctOrder.join(' '),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Available words:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _available.map((word) {
                      return Draggable<_WordItem>(
                        data: word,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _WordChip(
                            word: word,
                            dragging: true,
                            checked: false,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _WordChip(
                            word: word,
                            dragging: false,
                            checked: _isChecked,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: _isChecked ? null : () => _add(word),
                          child: _WordChip(
                            word: word,
                            dragging: false,
                            checked: _isChecked,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_available.isEmpty && !_isChecked) ...[
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'All words used! ✨',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                  if (!_isChecked) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFBFDBFE),
                          width: 2,
                        ),
                      ),
                      child: const Text(
                        '💡 Tip: Start with the subject (who is doing the action)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: !_isChecked
            ? SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canCheck ? _check : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canCheck
                        ? const Color(0xFFFA5C5C)
                        : const Color(0xFFE5E7EB),
                    foregroundColor: _canCheck
                        ? Colors.white
                        : const Color(0xFF9CA3AF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: const StadiumBorder(),
                    elevation: _canCheck ? 4 : 0,
                  ),
                  child: const Text(
                    'Check Answer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ok
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFFA5C5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: const StadiumBorder(),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!ok) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                            width: 2,
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.dragging,
    required this.checked,
  });
  final _WordItem word;
  final bool dragging, checked;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: checked ? const Color(0xFFE5E7EB) : const Color(0xFFD1D5DB),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: dragging ? const Color(0x30FA5C5C) : const Color(0x10000000),
            blurRadius: dragging ? 16 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator_rounded,
            size: 16,
            color: checked ? const Color(0xFFD1D5DB) : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 6),
          Text(
            word.text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: checked
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SHARED HEADER ────────────────────────────────────────────────────────────

class _ExerciseHeader extends StatelessWidget {
  const _ExerciseHeader({
    required this.progress,
    required this.total,
    required this.onClose,
  });
  final int progress, total;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 16,
        right: 20,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFF374151),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress / total,
                minHeight: 10,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFA5C5C),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$progress/$total',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── WAVEFORM PAINTER ─────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.animValue});
  final double animValue;
  static const _barCount = 28;
  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (_barCount * 2.0 - 1);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < _barCount; i++) {
      final wave = animValue > 0
          ? (math.sin(animValue * 2 * math.pi * 3 + i * 0.4) + 1) / 2
          : 0.0;
      final barHeight = size.height * 0.15 + size.height * 0.65 * wave;
      final x = i * (barWidth * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2, size.height / 2),
            width: barWidth,
            height: barHeight,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.animValue != animValue;
}

// ─────────────────────────────────────────────────────────────────────────────
// LESSON COMPLETED SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiPiece {
  _ConfettiPiece({
    required this.xFraction,
    required this.color,
    required this.isCircle,
    required this.size,
    required this.startDelay,
    required this.rotationSpeed,
  });
  final double xFraction, size, startDelay, rotationSpeed;
  final Color color;
  final bool isCircle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.animValue, required this.pieces});
  final double animValue;
  final List<_ConfettiPiece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final prog =
          ((animValue - piece.startDelay) / (1.0 - piece.startDelay + 0.001))
              .clamp(0.0, 1.0);
      if (prog <= 0) continue;
      final y = -30.0 + (size.height + 80) * prog;
      final x = piece.xFraction * size.width;
      final opacity = prog > 0.8 ? (1.0 - (prog - 0.8) / 0.2) : 1.0;
      final paint = Paint()
        ..color = piece.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotationSpeed * animValue);
      if (piece.isCircle) {
        canvas.drawCircle(Offset.zero, piece.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: piece.size,
            height: piece.size,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.animValue != animValue;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.bgColor,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final Color bgColor, iconColor;
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

class LessonCompletedScreen extends StatefulWidget {
  const LessonCompletedScreen({super.key});
  @override
  State<LessonCompletedScreen> createState() => _LessonCompletedScreenState();
}

class _LessonCompletedScreenState extends State<LessonCompletedScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiCtrl,
      _trophyCtrl,
      _starsCtrl,
      _contentCtrl,
      _scoreCtrl;
  late Animation<double> _trophyScale;
  late Animation<int> _scoreAnim;
  late List<_ConfettiPiece> _confettiPieces;
  bool _showConfetti = true;
  late int _score;
  late int _xp;
  late int _correctCount;
  late int _totalCount;

  @override
  void initState() {
    super.initState();
    final session = AppServices.exerciseSession;
    _score = session.scorePercent;
    _xp = session.xpEarned;
    _correctCount = session.correctCount;
    _totalCount = session.total;
    _saveProgress();
    final rng = math.Random(42);
    final colors = [
      const Color(0xFFFA5C5C),
      const Color(0xFFFD8A6B),
      const Color(0xFFFEC288),
      const Color(0xFFFBEF76),
    ];
    _confettiPieces = List.generate(
      50,
      (i) => _ConfettiPiece(
        xFraction: rng.nextDouble(),
        color: colors[i % 4],
        isCircle: rng.nextBool(),
        size: 6.0 + rng.nextDouble() * 6,
        startDelay: rng.nextDouble() * 0.3,
        rotationSpeed: (rng.nextDouble() - 0.5) * 8,
      ),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..forward();
    Future.delayed(const Duration(milliseconds: 4100), () {
      if (mounted) setState(() => _showConfetti = false);
    });

    _trophyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _trophyScale = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _trophyCtrl, curve: Curves.elasticOut));

    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scoreAnim = IntTween(
      begin: 0,
      end: _score,
    ).animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _trophyCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _starsCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) {
        _contentCtrl.forward();
        _scoreCtrl.forward();
      }
    });
  }

  Future<void> _saveProgress() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (user?.id == null) return;
    final lessonId = AppServices.exerciseSession.lessonId;
    await AppServices.learningRepository.completeLesson(
      userId: user!.id!,
      lessonId: lessonId > 0 ? lessonId : 4,
      score: _score,
      xpEarned: _xp,
    );
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _trophyCtrl.dispose();
    _starsCtrl.dispose();
    _contentCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    left: 24,
                    right: 24,
                    bottom: 24,
                  ),
                  child: Column(
                    children: [
                      // Trophy
                      ScaleTransition(
                        scale: _trophyScale,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFBEF76), Color(0xFFFEC288)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFEC288,
                                ).withValues(alpha: 0.5),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🏆', style: TextStyle(fontSize: 60)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Title
                      FadeTransition(
                        opacity: _trophyCtrl,
                        child: const Column(
                          children: [
                            Text(
                              'Hoàn Thành Bài Học! 🎉',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Học Màu Sắc',
                              style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Đơn Vị 1 - Bài 4',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Stars
                      AnimatedBuilder(
                        animation: _starsCtrl,
                        builder: (context, _) {
                          final earnedStars = _score >= 90
                              ? 3
                              : _score >= 70
                              ? 2
                              : _score >= 50
                              ? 1
                              : 0;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final t = ((_starsCtrl.value - i * 0.22) / 0.56)
                                  .clamp(0.0, 1.0);
                              final scale = i < earnedStars
                                  ? Curves.elasticOut.transform(t)
                                  : t * 0.6;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Transform.scale(
                                  scale: scale,
                                  child: Icon(
                                    Icons.star_rounded,
                                    size: 60,
                                    color: i < earnedStars
                                        ? const Color(0xFFFBEF76)
                                        : const Color(0xFFD1D5DB),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      // Score Card
                      FadeTransition(
                        opacity: _contentCtrl,
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
                                color: const Color(
                                  0xFFFA5C5C,
                                ).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 40,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -16,
                                right: -16,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Điểm Số',
                                    style: TextStyle(
                                      fontSize: 13,
                                      letterSpacing: 1.0,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedBuilder(
                                    animation: _scoreAnim,
                                    builder: (context, _) => RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${_scoreAnim.value}',
                                            style: const TextStyle(
                                              fontSize: 68,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: '%',
                                            style: TextStyle(
                                              fontSize: 38,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+$_xp XP',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Stats
                      FadeTransition(
                        opacity: _contentCtrl,
                        child: Row(
                          children: [
                            _StatTile(
                              bgColor: const Color(0xFFDCFCE7),
                              icon: Icons.trending_up_rounded,
                              iconColor: const Color(0xFF16A34A),
                              value: '$_score%',
                              label: 'Độ Chính Xác',
                            ),
                            const SizedBox(width: 10),
                            const _StatTile(
                              bgColor: Color(0xFFDBEAFE),
                              icon: Icons.access_time_rounded,
                              iconColor: Color(0xFF2563EB),
                              value: '--:--',
                              label: 'Thời Gian',
                            ),
                            const SizedBox(width: 10),
                            _StatTile(
                              bgColor: const Color(0xFFF3E8FF),
                              icon: Icons.star_rounded,
                              iconColor: const Color(0xFF7C3AED),
                              value: '$_correctCount/$_totalCount',
                              label: 'Đúng',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Encouragement message
                      FadeTransition(
                        opacity: _contentCtrl,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0x33FBEF76), Color(0x33FEC288)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0x4DFEC288),
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Text(
                            '🌟 Xuất sắc! Bạn thật có tài năng!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Confetti overlay
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiCtrl,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(
                      animValue: _confettiCtrl.value,
                      pieces: _confettiPieces,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: FadeTransition(
        opacity: _contentCtrl,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA5C5C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: const StadiumBorder(),
                    elevation: 4,
                    shadowColor: const Color(0x40FA5C5C),
                  ),
                  child: const Text(
                    'Tiếp Tục Học',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/leaderboard'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
                  ),
                  child: const Text(
                    'Xem Bảng Xếp Hạng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
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

// ─────────────────────────────────────────────────────────────────────────────
// FLASHCARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _FlashcardData {
  const _FlashcardData({
    required this.word,
    required this.translation,
    required this.phonetic,
    required this.example,
    required this.illustration,
    required this.gradStart,
    required this.gradEnd,
  });
  final String word, translation, phonetic, example, illustration;
  final Color gradStart, gradEnd;
}

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key, this.isExercise = false});
  final bool isExercise;
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  late PageController _pageCtrl;

  static const _cards = [
    _FlashcardData(
      word: 'Happy',
      translation: 'Vui Vẻ',
      phonetic: '/ˈhæpi/',
      example: 'I am happy today',
      illustration: '😊',
      gradStart: Color(0xFFFBEF76),
      gradEnd: Color(0xFFFEC288),
    ),
    _FlashcardData(
      word: 'Beautiful',
      translation: 'Xinh Đẹp',
      phonetic: '/ˈbjuːtɪfəl/',
      example: 'The flower is beautiful',
      illustration: '🌸',
      gradStart: Color(0xFFFD8A6B),
      gradEnd: Color(0xFFFA5C5C),
    ),
    _FlashcardData(
      word: 'Friendly',
      translation: 'Thân Thiện',
      phonetic: '/ˈfrendli/',
      example: 'She is very friendly',
      illustration: '🤝',
      gradStart: Color(0xFFFEC288),
      gradEnd: Color(0xFFFD8A6B),
    ),
    _FlashcardData(
      word: 'Delicious',
      translation: 'Thơm Ngon',
      phonetic: '/dɪˈlɪʃəs/',
      example: 'This food is delicious',
      illustration: '🍕',
      gradStart: Color(0xFFFA5C5C),
      gradEnd: Color(0xFFFD8A6B),
    ),
    _FlashcardData(
      word: 'Exciting',
      translation: 'Thú Vị',
      phonetic: '/ɪkˈsaɪtɪŋ/',
      example: 'The game is exciting',
      illustration: '🎉',
      gradStart: Color(0xFFFBEF76),
      gradEnd: Color(0xFFFEC288),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFlipped) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _goNext() {
    if (_currentIndex < _cards.length - 1) {
      _flipCtrl.value = 0;
      setState(() => _isFlipped = false);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _goPrev() {
    if (_currentIndex > 0) {
      _flipCtrl.value = 0;
      setState(() => _isFlipped = false);
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildFrontFace(_FlashcardData card) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [card.gradStart, card.gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: card.gradEnd.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(card.illustration, style: const TextStyle(fontSize: 80)),
                  const SizedBox(height: 22),
                  Text(
                    card.word,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    card.phonetic,
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 26),
                  GestureDetector(
                    onTap: () => AppServices.tts.speak(card.word),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Phát Âm',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.flip_rounded,
                        size: 15,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Nhấn để xem nghĩa',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackFace(_FlashcardData card) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Nghĩa',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            card.translation,
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ví Dụ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${card.example}"',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(card.illustration, style: const TextStyle(fontSize: 46)),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flip_rounded, size: 15, color: Color(0xFFD1D5DB)),
              SizedBox(width: 6),
              Text(
                'Nhấn để lật lại',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / _cards.length;
    final isLast = _currentIndex == _cards.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Ôn Từ Vựng',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiến độ',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    Text(
                      '${_currentIndex + 1} / ${_cards.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFA5C5C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Card area
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Nhấn thẻ để lật  •  Vuốt để di chuyển',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _cards.length,
                    onPageChanged: (index) {
                      _flipCtrl.value = 0;
                      setState(() {
                        _currentIndex = index;
                        _isFlipped = false;
                      });
                    },
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: _flip,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedBuilder(
                          animation: _flipAnim,
                          builder: (context, _) {
                            final angle =
                                (index == _currentIndex
                                    ? _flipAnim.value
                                    : 0.0) *
                                math.pi;
                            final showFront = angle < math.pi / 2;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              child: showFront
                                  ? _buildFrontFace(_cards[index])
                                  : Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateY(math.pi),
                                      child: _buildBackFace(_cards[index]),
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Navigation row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FlashNavBtn(
                        onTap: _currentIndex > 0 ? _goPrev : null,
                        icon: Icons.chevron_left_rounded,
                      ),
                      const Row(
                        children: [
                          Icon(
                            Icons.swipe_rounded,
                            size: 16,
                            color: Color(0xFFD1D5DB),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Vuốt để qua lại',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      _FlashNavBtn(
                        onTap: _currentIndex < _cards.length - 1
                            ? _goNext
                            : null,
                        icon: Icons.chevron_right_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLast
                ? () => context.go(
                    widget.isExercise ? '/lesson-completed' : '/home',
                  )
                : _goNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA5C5C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: const StadiumBorder(),
              elevation: 4,
              shadowColor: const Color(0x40FA5C5C),
            ),
            child: Text(
              isLast ? 'Hoàn Thành Ôn Tập' : 'Thẻ Tiếp Theo',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlashNavBtn extends StatelessWidget {
  const _FlashNavBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(50),
          border: enabled
              ? Border.all(color: const Color(0xFFE5E7EB), width: 2)
              : null,
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 26,
          color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}
