import 'package:shared_preferences/shared_preferences.dart';

class RouteStateService {
  static const String _lastRouteKey = 'last_route';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String? getLastRestorableRoute() {
    final route = _prefs?.getString(_lastRouteKey);
    if (route == null || !_isRestorableRoute(route)) {
      return null;
    }
    return route;
  }

  Future<void> saveRoute(String route) async {
    if (!_isRestorableRoute(route)) return;
    await _prefs?.setString(_lastRouteKey, route);
  }

  Future<void> clear() async {
    await _prefs?.remove(_lastRouteKey);
  }

  bool _isRestorableRoute(String route) {
    final uri = Uri.tryParse(route);
    final path = uri?.path ?? route;

    const blockedRoutes = {'/', '/login', '/register'};
    if (blockedRoutes.contains(path)) return false;
    if (path.startsWith('/onboarding')) return false;

    return path.startsWith('/');
  }
}
