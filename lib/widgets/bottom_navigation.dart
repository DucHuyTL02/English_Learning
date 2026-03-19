import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Mô tả một tab trong bottom navigation bar.
class _TabItem {
  final String id;
  final String label;
  final IconData icon;
  final String path;
  final Color color;

  const _TabItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.path,
    required this.color,
  });
}

/// Bottom navigation bar hiển thị cố định ở dưới màn hình.
/// Dịch từ file React BottomNavigation.tsx.
class BottomNavigationBar2 extends StatelessWidget {
  const BottomNavigationBar2({super.key});

  static const List<_TabItem> _tabs = [
    _TabItem(
      id: 'home',
      label: 'Trang Chủ',
      icon: Icons.home_rounded,
      path: '/home',
      color: Color(0xFFFA5C5C),
    ),
    _TabItem(
      id: 'learn',
      label: 'Học Tập',
      icon: Icons.menu_book_rounded,
      path: '/course-map',
      color: Color(0xFFFD8A6B),
    ),
    _TabItem(
      id: 'dictionary',
      label: 'Từ Điển',
      icon: Icons.library_books_rounded,
      path: '/dictionary',
      color: Color(0xFFFEC288),
    ),
    _TabItem(
      id: 'leaderboard',
      label: 'Xếp Hạng',
      icon: Icons.emoji_events_rounded,
      path: '/leaderboard',
      color: Color(0xFFFBEF76),
    ),
    _TabItem(
      id: 'profile',
      label: 'Cá Nhân',
      icon: Icons.person_rounded,
      path: '/profile',
      color: Color(0xFFFA5C5C),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final String currentPath = GoRouterState.of(context).uri.toString();

    return _AnimatedBottomNav(tabs: _tabs, currentPath: currentPath);
  }
}

class _AnimatedBottomNav extends StatefulWidget {
  final List<_TabItem> tabs;
  final String currentPath;

  const _AnimatedBottomNav({
    required this.tabs,
    required this.currentPath,
  });

  @override
  State<_AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<_AnimatedBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_slideController);

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  bool _isActive(String path) => widget.currentPath == path;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: widget.tabs
                    .map((tab) => _TabButton(
                          tab: tab,
                          active: _isActive(tab.path),
                          showNotificationDot: tab.id == 'profile' &&
                              widget.currentPath == '/notifications',
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  final _TabItem tab;
  final bool active;
  final bool showNotificationDot;

  const _TabButton({
    required this.tab,
    required this.active,
    required this.showNotificationDot,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _offsetAnimation = Tween<double>(begin: 0.0, end: -2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _TabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward();
    } else if (!widget.active && oldWidget.active) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final active = widget.active;

    return GestureDetector(
      onTap: () => context.go(tab.path),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Active top indicator bar
            if (active)
              Positioned(
                top: -10,
                child: _ActiveIndicator(color: tab.color),
              ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon container with spring animation
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _offsetAnimation.value),
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: active
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                tab.color,
                                tab.color.withAlpha(0xDD),
                              ],
                            )
                          : null,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: tab.color.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      tab.icon,
                      size: 22,
                      color: active ? Colors.white : Colors.grey.shade400,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? tab.color : Colors.grey.shade400,
                    height: 1.2,
                  ),
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Notification red dot
            if (widget.showNotificationDot)
              Positioned(
                top: 0,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA5C5C),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget thanh chỉ báo active phía trên icon tab.
class _ActiveIndicator extends StatefulWidget {
  final Color color;
  const _ActiveIndicator({required this.color});

  @override
  State<_ActiveIndicator> createState() => _ActiveIndicatorState();
}

class _ActiveIndicatorState extends State<_ActiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _widthAnim = Tween<double>(begin: 0, end: 40).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnim,
      builder: (context, _) {
        return Container(
          width: _widthAnim.value,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [widget.color, widget.color.withAlpha(0xDD)],
            ),
          ),
        );
      },
    );
  }
}
