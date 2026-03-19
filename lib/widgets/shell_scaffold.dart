import 'package:flutter/material.dart';
import 'bottom_navigation.dart';

/// Scaffold bao bọc các màn hình chính (Home, Learn, Dictionary, Leaderboard, Profile)
/// để hiển thị BottomNavigationBar2 phía dưới.
class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const BottomNavigationBar2(),
    );
  }
}
