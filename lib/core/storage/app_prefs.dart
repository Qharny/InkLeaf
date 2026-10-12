import 'package:flutter/material.dart';
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
  static const _recentSearchesKey = 'recent_searches';
  static const _themeModeKey = 'theme_mode';
  static const _appLockKey = 'app_lock';
  static const _starterAddedKey = 'starter_added';
  static const _maxRecentSearches = 8;

  final SharedPreferences _prefs;

  bool get onboardingDone => _prefs.getBool(_onboardingDoneKey) ?? false;

  Future<void> completeOnboarding() => _prefs.setBool(_onboardingDoneKey, true);

  /// Shows the intro again on the next launch.
  Future<void> resetOnboarding() => _prefs.setBool(_onboardingDoneKey, false);

  /// Whether the starter notebook has been offered, so it's added at most
  /// once, even after every note is deleted.
  bool get starterAdded => _prefs.getBool(_starterAddedKey) ?? false;

  Future<void> markStarterAdded() => _prefs.setBool(_starterAddedKey, true);

  /// Whether Inkleaf asks for the phone's fingerprint, face or PIN.
  bool get appLock => _prefs.getBool(_appLockKey) ?? false;

  Future<void> setAppLock(bool value) => _prefs.setBool(_appLockKey, value);

  /// Light paper (the default), the night desk, or whatever the system uses.
  late final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.values.asNameMap()[_prefs.getString(_themeModeKey)] ??
        ThemeMode.light,
  );

  Future<void> setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    return _prefs.setString(_themeModeKey, mode.name);
  }

  /// Whether the home screen shows notes as a grid (true) or a list.
  bool get homeGrid => _prefs.getBool(_homeGridKey) ?? true;

  Future<void> setHomeGrid(bool value) => _prefs.setBool(_homeGridKey, value);

  /// Name of the chosen `NoteSort`.
  String? get noteSort => _prefs.getString(_noteSortKey);

  Future<void> setNoteSort(String value) =>
      _prefs.setString(_noteSortKey, value);

  /// Past searches, newest first.
  List<String> get recentSearches =>
      _prefs.getStringList(_recentSearchesKey) ?? const [];

  /// Moves [query] to the front of [recentSearches], keeping the list short.
  Future<void> addRecentSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return Future.value();
    final list = [
      q,
      ...recentSearches.where((s) => s.toLowerCase() != q.toLowerCase()),
    ].take(_maxRecentSearches).toList();
    return _prefs.setStringList(_recentSearchesKey, list);
  }

  Future<void> removeRecentSearch(String query) => _prefs.setStringList(
    _recentSearchesKey,
    recentSearches.where((s) => s != query).toList(),
  );

  Future<void> clearRecentSearches() => _prefs.remove(_recentSearchesKey);
}
