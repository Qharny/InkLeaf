import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value settings, loaded once before the app starts.
class AppPrefs {
  AppPrefs._(this._prefs);

  static late AppPrefs instance;

  static Future<void> init() async {
    instance = AppPrefs._(await SharedPreferences.getInstance());
  }

  static const _onboardingDoneKey = 'onboarding_done';

  final SharedPreferences _prefs;

  bool get onboardingDone => _prefs.getBool(_onboardingDoneKey) ?? false;

  Future<void> completeOnboarding() => _prefs.setBool(_onboardingDoneKey, true);
}
