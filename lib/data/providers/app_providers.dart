import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/app_services.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ThemeNotifier — quản lý ThemeMode (light / dark / system)
// ═══════════════════════════════════════════════════════════════════════════

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setDark(bool isDark) =>
      state = isDark ? ThemeMode.dark : ThemeMode.light;

  void setMode(ThemeMode mode) => state = mode;
}

final themeNotifierProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

// ═══════════════════════════════════════════════════════════════════════════
// LocaleNotifier — quản lý ngôn ngữ hiển thị (vi / en)
// ═══════════════════════════════════════════════════════════════════════════

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('vi');

  void setLocale(Locale locale) => state = locale;

  bool get isVietnamese => state.languageCode == 'vi';
}

final localeNotifierProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

// ═══════════════════════════════════════════════════════════════════════════
// ActiveUserNotifier — user đang đăng nhập, đồng bộ từ SQLite
// ═══════════════════════════════════════════════════════════════════════════

class ActiveUserNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    final user = await AppServices.userRepository.getActiveUser();
    if (user?.id != null) {
      // Kiểm tra & tắt Premium nếu hết hạn
      return await AppServices.userRepository.checkAndExpirePremium(user!.id!);
    }
    return user;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => AppServices.userRepository.getActiveUser(),
    );
  }

  void clear() => state = const AsyncData(null);
}

final activeUserProvider =
    AsyncNotifierProvider<ActiveUserNotifier, UserModel?>(
      ActiveUserNotifier.new,
    );
