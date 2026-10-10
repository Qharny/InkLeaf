import 'package:shared_preferences/shared_preferences.dart';

/// Small key-value settings, loaded once before the app starts.
class AppPrefs {
  AppPrefs._(this._prefs);

  static late AppPrefs instance;

  static Future<void> init() async {
    instance = AppPrefs._(await SharedPreferences.getInstance());
  }

  static const _onboardingDoneKey = 'onboarding_done';
  static const _homeGridKey = 'home_grid';
  static const _noteSortKey = 'note_sort';

  final SharedPreferences _prefs;

  bool get onboardingDone => _prefs.getBool(_onboardingDoneKey) ?? false;

  Future<void> completeOnboarding() => _prefs.setBool(_onboardingDoneKey, true);

  /// Whether the home screen shows notes as a grid (true) or a list.
  bool get homeGrid => _prefs.getBool(_homeGridKey) ?? true;

  Future<void> setHomeGrid(bool value) => _prefs.setBool(_homeGridKey, value);

  /// Name of the chosen `NoteSort`.
  String? get noteSort => _prefs.getString(_noteSortKey);

  Future<void> setNoteSort(String value) =>
      _prefs.setString(_noteSortKey, value);
}
