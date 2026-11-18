import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Lets one specific demo/test account simulate disruptive weather and
/// heavy traffic so live-condition features (rain warnings, re-optimise
/// prompts, congestion banners) can be demoed without waiting for real
/// weather or real traffic to occur.
///
/// This is intentionally restricted to a single account
/// ([_allowedEmail]) so it can never be switched on for a real user by
/// accident — the toggle itself is only rendered for that account, and the
/// flag is ignored for every other account even if somehow set.
class DemoModeService extends ChangeNotifier {
  DemoModeService._();
  static final DemoModeService instance = DemoModeService._();

  static const String _allowedEmail = 'yyyy6262yyyy6262@gmail.com';
  static const String _prefsKey = 'demo_mode_enabled';

  bool _enabled = false;
  bool _loaded = false;

  /// Whether the currently signed-in account is allowed to see/use Demo Mode.
  bool get isAllowedForCurrentUser =>
      AuthService.instance.currentUser?.email?.trim().toLowerCase() == _allowedEmail;

  /// Whether Demo Mode is actually active right now. Always false for any
  /// account other than [_allowedEmail], regardless of the stored flag.
  bool get enabled => isAllowedForCurrentUser && _enabled;

  /// Loads the persisted flag. Safe to call multiple times; only the first
  /// call does any work. Call once during app startup.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      _enabled = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!isAllowedForCurrentUser) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // Ignore persistence failures — the in-memory flag still works for
      // the rest of this session.
    }
  }

  // ---- Fixed demo data -----------------------------------------------

  /// A clearly-disruptive weather code (thunderstorm) used in place of a
  /// real forecast when Demo Mode is on.
  static const int demoWeatherCode = 95;
  static const double demoTempC = 24;

  /// Rain windows covering the whole afternoon/evening, so any outdoor
  /// activity scheduled after midday shows as weather-at-risk.
  static const List<({int start, int end})> demoRainWindows = [(start: 12 * 60, end: 23 * 60)];

  /// A fixed, clearly-congested travel time: declared "typical" time is 10
  /// minutes, actual time is 32 minutes — well past the isCongested
  /// threshold (>=600s extra AND >=1.3x typical).
  static const int demoTravelTimeSeconds = 32 * 60;
  static const int demoStaticDurationSeconds = 10 * 60;
  static const int demoLengthMeters = 6500;
}
