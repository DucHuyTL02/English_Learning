import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Lớp đa ngôn ngữ thủ công (vi + en).
/// Sử dụng qua `AppLocalizations.of(context).someKey`.
class AppLocalizations {
  AppLocalizations._(this.locale);

  final Locale locale;

  // ── Tra cứu từ context ────────────────────────────────────────────────
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('vi'),
    Locale('en'),
  ];

  // Trả về map cho ngôn ngữ hiện tại, fallback sang tiếng Việt.
  Map<String, String> get _m => _strings[locale.languageCode] ?? _strings['vi']!;

  String _t(String key) => _m[key] ?? key;

  // ── Chung ────────────────────────────────────────────────────────────────
  String get appName => _t('appName');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get confirm => _t('confirm');
  String get close => _t('close');
  String get yes => _t('yes');
  String get no => _t('no');
  String get ok => _t('ok');
  String get loading => _t('loading');
  String get error => _t('error');
  String get success => _t('success');
  String get retry => _t('retry');
  String get search => _t('search');
  String get noData => _t('noData');

  // ── Greeting ─────────────────────────────────────────────────────────────
  String greeting(String name) => _t('greeting').replaceFirst('{name}', name);
  String welcome(String name) => _t('welcome').replaceFirst('{name}', name);

  // ── Auth ─────────────────────────────────────────────────────────────────
  String get loginTitle => _t('loginTitle');
  String get loginButton => _t('loginButton');
  String get registerTitle => _t('registerTitle');
  String get registerButton => _t('registerButton');
  String get logout => _t('logout');
  String get logoutConfirm => _t('logoutConfirm');
  String get email => _t('email');
  String get password => _t('password');
  String get fullName => _t('fullName');
  String get forgotPassword => _t('forgotPassword');
  String get alreadyHaveAccount => _t('alreadyHaveAccount');
  String get dontHaveAccount => _t('dontHaveAccount');

  // ── Điều hướng ───────────────────────────────────────────────────────────
  String get navHome => _t('navHome');
  String get navCourse => _t('navCourse');
  String get navDictionary => _t('navDictionary');
  String get navLeaderboard => _t('navLeaderboard');
  String get navProfile => _t('navProfile');

  // ── Trang chủ ────────────────────────────────────────────────────────────
  String get homeTitle => _t('homeTitle');
  String get continueLearning => _t('continueLearning');
  String get dailyGoal => _t('dailyGoal');
  String get todayProgress => _t('todayProgress');
  String get streakLabel => _t('streakLabel');
  String streakDays(int days) =>
      _t('streakDays').replaceFirst('{days}', '$days');

  // ── Bài học ──────────────────────────────────────────────────────────────
  String get lessonTitle => _t('lessonTitle');
  String get startLesson => _t('startLesson');
  String get continueLesson => _t('continueLesson');
  String get lessonCompleted => _t('lessonCompleted');
  String get locked => _t('locked');
  String get unlockLesson => _t('unlockLesson');

  // ── Từ điển ──────────────────────────────────────────────────────────────
  String get dictionaryTitle => _t('dictionaryTitle');
  String get searchWord => _t('searchWord');
  String get savedWords => _t('savedWords');
  String get noSavedWords => _t('noSavedWords');
  String get addToSaved => _t('addToSaved');
  String get removeFromSaved => _t('removeFromSaved');

  // ── Bảng xếp hạng ────────────────────────────────────────────────────────
  String get leaderboardTitle => _t('leaderboardTitle');
  String get myRank => _t('myRank');
  String get xpLabel => _t('xpLabel');
  String rankLabel(int rank) => _t('rankLabel').replaceFirst('{rank}', '#$rank');

  // ── Thành tích ──────────────────────────────────────────────────────────
  String get achievementsTitle => _t('achievementsTitle');
  String get newAchievement => _t('newAchievement');
  String achievementUnlocked(String name) =>
      _t('achievementUnlocked').replaceFirst('{name}', name);

  // ── Hồ sơ / Cài đặt ─────────────────────────────────────────────────────
  String get profileTitle => _t('profileTitle');
  String get settingsTitle => _t('settingsTitle');
  String get language => _t('language');
  String get darkMode => _t('darkMode');
  String get notifications => _t('notifications');
  String get sound => _t('sound');
  String get chooseLanguage => _t('chooseLanguage');
  String get vietnamese => _t('vietnamese');
  String get english => _t('english');
  String get editProfile => _t('editProfile');
  String get changePassword => _t('changePassword');
  String get aboutApp => _t('aboutApp');
  String get helpSupport => _t('helpSupport');
  String get version => _t('version');
}

// ════════════════════════════════════════════════════════════════════════════
// Chuỗi tiếng Việt
// ════════════════════════════════════════════════════════════════════════════
const Map<String, String> _vi = {
  'appName': 'English Learning',
  'cancel': 'Hủy',
  'save': 'Lưu',
  'confirm': 'Xác nhận',
  'close': 'Đóng',
  'yes': 'Có',
  'no': 'Không',
  'ok': 'OK',
  'loading': 'Đang tải…',
  'error': 'Lỗi',
  'success': 'Thành công',
  'retry': 'Thử lại',
  'search': 'Tìm kiếm',
  'noData': 'Không có dữ liệu',

  'greeting': 'Xin chào, {name}!',
  'welcome': 'Chào mừng {name}!',

  'loginTitle': 'Đăng nhập',
  'loginButton': 'Đăng Nhập',
  'registerTitle': 'Đăng ký',
  'registerButton': 'Tạo Tài Khoản',
  'logout': 'Đăng xuất',
  'logoutConfirm': 'Bạn có chắc muốn đăng xuất?',
  'email': 'Email',
  'password': 'Mật khẩu',
  'fullName': 'Họ & Tên',
  'forgotPassword': 'Quên mật khẩu?',
  'alreadyHaveAccount': 'Đã có tài khoản? Đăng nhập',
  'dontHaveAccount': 'Chưa có tài khoản? Đăng ký',

  'navHome': 'Trang chủ',
  'navCourse': 'Khóa học',
  'navDictionary': 'Từ điển',
  'navLeaderboard': 'Xếp hạng',
  'navProfile': 'Hồ sơ',

  'homeTitle': 'Trang Chủ',
  'continueLearning': 'Tiếp tục học',
  'dailyGoal': 'Mục tiêu hôm nay',
  'todayProgress': 'Tiến độ hôm nay',
  'streakLabel': 'Chuỗi ngày',
  'streakDays': '{days} ngày',

  'lessonTitle': 'Bài học',
  'startLesson': 'Bắt đầu',
  'continueLesson': 'Tiếp tục',
  'lessonCompleted': 'Hoàn thành!',
  'locked': 'Đã khóa',
  'unlockLesson': 'Mở khóa bài học',

  'dictionaryTitle': 'Từ Điển',
  'searchWord': 'Tìm từ vựng…',
  'savedWords': 'Từ đã lưu',
  'noSavedWords': 'Chưa có từ nào được lưu',
  'addToSaved': 'Lưu từ này',
  'removeFromSaved': 'Xóa khỏi danh sách',

  'leaderboardTitle': 'Bảng Xếp Hạng',
  'myRank': 'Hạng của tôi',
  'xpLabel': 'XP',
  'rankLabel': '{rank}',

  'achievementsTitle': 'Thành Tích',
  'newAchievement': 'Thành tích mới!',
  'achievementUnlocked': 'Đã mở khóa: {name}',

  'profileTitle': 'Hồ Sơ',
  'settingsTitle': 'Cài Đặt',
  'language': 'Ngôn ngữ',
  'darkMode': 'Chế độ tối',
  'notifications': 'Thông báo',
  'sound': 'Âm thanh',
  'chooseLanguage': 'Chọn ngôn ngữ',
  'vietnamese': 'Tiếng Việt',
  'english': 'English',
  'editProfile': 'Chỉnh sửa hồ sơ',
  'changePassword': 'Đổi mật khẩu',
  'aboutApp': 'Giới thiệu ứng dụng',
  'helpSupport': 'Trợ giúp & Hỗ trợ',
  'version': 'Phiên bản',
};

// ════════════════════════════════════════════════════════════════════════════
// Chuỗi tiếng Anh
// ════════════════════════════════════════════════════════════════════════════
const Map<String, String> _en = {
  'appName': 'English Learning',
  'cancel': 'Cancel',
  'save': 'Save',
  'confirm': 'Confirm',
  'close': 'Close',
  'yes': 'Yes',
  'no': 'No',
  'ok': 'OK',
  'loading': 'Loading…',
  'error': 'Error',
  'success': 'Success',
  'retry': 'Retry',
  'search': 'Search',
  'noData': 'No data available',

  'greeting': 'Hello, {name}!',
  'welcome': 'Welcome, {name}!',

  'loginTitle': 'Sign In',
  'loginButton': 'Sign In',
  'registerTitle': 'Create Account',
  'registerButton': 'Create Account',
  'logout': 'Sign out',
  'logoutConfirm': 'Are you sure you want to sign out?',
  'email': 'Email',
  'password': 'Password',
  'fullName': 'Full Name',
  'forgotPassword': 'Forgot password?',
  'alreadyHaveAccount': 'Already have an account? Sign in',
  'dontHaveAccount': "Don't have an account? Register",

  'navHome': 'Home',
  'navCourse': 'Courses',
  'navDictionary': 'Dictionary',
  'navLeaderboard': 'Leaderboard',
  'navProfile': 'Profile',

  'homeTitle': 'Home',
  'continueLearning': 'Continue learning',
  'dailyGoal': "Today's goal",
  'todayProgress': 'Progress today',
  'streakLabel': 'Streak',
  'streakDays': '{days} days',

  'lessonTitle': 'Lesson',
  'startLesson': 'Start',
  'continueLesson': 'Continue',
  'lessonCompleted': 'Completed!',
  'locked': 'Locked',
  'unlockLesson': 'Unlock lesson',

  'dictionaryTitle': 'Dictionary',
  'searchWord': 'Search words…',
  'savedWords': 'Saved words',
  'noSavedWords': 'No saved words yet',
  'addToSaved': 'Save this word',
  'removeFromSaved': 'Remove from saved',

  'leaderboardTitle': 'Leaderboard',
  'myRank': 'My rank',
  'xpLabel': 'XP',
  'rankLabel': '{rank}',

  'achievementsTitle': 'Achievements',
  'newAchievement': 'New achievement!',
  'achievementUnlocked': 'Unlocked: {name}',

  'profileTitle': 'Profile',
  'settingsTitle': 'Settings',
  'language': 'Language',
  'darkMode': 'Dark mode',
  'notifications': 'Notifications',
  'sound': 'Sound',
  'chooseLanguage': 'Choose language',
  'vietnamese': 'Tiếng Việt',
  'english': 'English',
  'editProfile': 'Edit profile',
  'changePassword': 'Change password',
  'aboutApp': 'About the app',
  'helpSupport': 'Help & Support',
  'version': 'Version',
};

const Map<String, Map<String, String>> _strings = {'vi': _vi, 'en': _en};

// ════════════════════════════════════════════════════════════════════════════
// Delegate
// ════════════════════════════════════════════════════════════════════════════
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations._(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
