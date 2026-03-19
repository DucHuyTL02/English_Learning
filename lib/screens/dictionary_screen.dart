import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────
class _Word {
  final int id;
  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String definition;
  final String example;
  bool saved;
  final String dateAdded;

  _Word({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.definition,
    required this.example,
    required this.saved,
    required this.dateAdded,
  });

  _Word copyWith({bool? saved}) => _Word(
        id: id,
        word: word,
        phonetic: phonetic,
        partOfSpeech: partOfSpeech,
        definition: definition,
        example: example,
        saved: saved ?? this.saved,
        dateAdded: dateAdded,
      );
}

final _initialWords = [
  _Word(
    id: 1,
    word: 'Beautiful',
    phonetic: '/ˈbjuːtɪfəl/',
    partOfSpeech: 'adjective',
    definition: 'Pleasing the senses or mind aesthetically',
    example: 'The flower is beautiful',
    saved: true,
    dateAdded: '2 days ago',
  ),
  _Word(
    id: 2,
    word: 'Delicious',
    phonetic: '/dɪˈlɪʃəs/',
    partOfSpeech: 'adjective',
    definition: 'Highly pleasant to the taste',
    example: 'This food is delicious',
    saved: true,
    dateAdded: '3 days ago',
  ),
  _Word(
    id: 3,
    word: 'Exciting',
    phonetic: '/ɪkˈsaɪtɪŋ/',
    partOfSpeech: 'adjective',
    definition: 'Causing great enthusiasm and eagerness',
    example: 'The game is exciting',
    saved: true,
    dateAdded: '5 days ago',
  ),
  _Word(
    id: 4,
    word: 'Wonderful',
    phonetic: '/ˈwʌndərfəl/',
    partOfSpeech: 'adjective',
    definition: 'Inspiring delight, pleasure, or admiration',
    example: "It's a wonderful day",
    saved: true,
    dateAdded: '1 week ago',
  ),
  _Word(
    id: 5,
    word: 'Magnificent',
    phonetic: '/mæɡˈnɪfɪsənt/',
    partOfSpeech: 'adjective',
    definition: 'Impressively beautiful, elaborate, or extravagant',
    example: 'The view is magnificent',
    saved: true,
    dateAdded: '1 week ago',
  ),
];

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
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
  String _searchQuery = '';
  String _activeTab = 'saved'; // 'saved' | 'all'
  List<_Word> _words = List.from(_initialWords);

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
    ).animate(
        CurvedAnimation(parent: _footerCtrl, curve: Curves.easeOut));
    _footerFade = CurvedAnimation(parent: _footerCtrl, curve: Curves.easeOut);

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _footerCtrl.forward();
    });

    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleBookmark(int id) {
    setState(() {
      _words = _words.map((w) => w.id == id ? w.copyWith(saved: !w.saved) : w).toList();
    });
  }

  List<_Word> get _filteredWords => _words.where((w) {
        final matchesSearch =
            w.word.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesTab = _activeTab == 'all' || w.saved;
        return matchesSearch && matchesTab;
      }).toList();

  int get _savedCount => _words.where((w) => w.saved).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
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
                  onTabChanged: (t) => setState(() => _activeTab = t),
                  onClearSearch: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ),
            ),
          ),

          // ── Word List ────────────────────────────────────────────────────
          if (_filteredWords.isEmpty)
            SliverToBoxAdapter(child: _EmptyState(searchQuery: _searchQuery))
          else
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _WordCard(
                    word: _filteredWords[i],
                    index: i,
                    onToggleBookmark: _toggleBookmark,
                  ),
                  childCount: _filteredWords.length,
                ),
              ),
            ),

          // ── Stats Footer ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _footerSlide,
              child: FadeTransition(
                opacity: _footerFade,
                child: _StatsFooter(savedCount: _savedCount),
              ),
            ),
          ),

          // Bottom padding for nav bar
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Header Section
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int savedCount;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onClearSearch;

  const _Header({
    required this.savedCount,
    required this.searchCtrl,
    required this.searchQuery,
    required this.activeTab,
    required this.onTabChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
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
                      child: const Icon(Icons.arrow_back,
                          size: 20, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Dictionary',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text('Your saved vocabulary',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
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
                    child: const Center(
                        child: Text('📚', style: TextStyle(fontSize: 22))),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search bar
              Container(
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFE5E7EB), width: 2),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.search,
                        size: 20, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search words...',
                          hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1F2937)),
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: onClearSearch,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: Icon(Icons.close,
                              size: 20, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tab switcher
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
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

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
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color: active
                        ? const Color(0xFF111827)
                        : const Color(0xFF6B7280)),
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

// ─────────────────────────────────────────────
// Word Card
// ─────────────────────────────────────────────
class _WordCard extends StatefulWidget {
  final _Word word;
  final int index;
  final ValueChanged<int> onToggleBookmark;

  const _WordCard({
    required this.word,
    required this.index,
    required this.onToggleBookmark,
  });

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
    final w = widget.word;
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Word title + speaker
                    Row(
                      children: [
                        Text(
                          w.word,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFA5C5C),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.volume_up,
                              size: 18, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Phonetic
                    Text(
                      w.phonetic,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Part of speech chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x33FEC288),
                            Color(0x33FBEF76),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        w.partOfSpeech,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Definition
                    Text(
                      w.definition,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),

                    // Example sentence
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '"${w.example}"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Date added
                    Text(
                      'Added ${w.dateAdded}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),

              // Bookmark button
              GestureDetector(
                onTap: () => widget.onToggleBookmark(w.id),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: w.saved
                        ? const Icon(Icons.bookmark,
                            key: ValueKey('saved'),
                            size: 24,
                            color: Color(0xFFFA5C5C))
                        : const Icon(Icons.bookmark_border,
                            key: ValueKey('unsaved'),
                            size: 24,
                            color: Color(0xFFD1D5DB)),
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

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String searchQuery;
  const _EmptyState({required this.searchQuery});

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
                child: Text('📖', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 16),
          const Text('No words found',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827))),
          const SizedBox(height: 6),
          Text(
            searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Save words from lessons to see them here',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stats Footer
// ─────────────────────────────────────────────
class _StatsFooter extends StatelessWidget {
  final int savedCount;
  const _StatsFooter({required this.savedCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
                color: const Color(0xFFFA5C5C).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Decoration circle
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
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
                          Text('Total Saved Words',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8))),
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
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                            child:
                                Text('📖', style: TextStyle(fontSize: 28))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Keep learning and expanding your vocabulary! 🚀',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
