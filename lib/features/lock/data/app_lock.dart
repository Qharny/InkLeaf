import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/storage/app_prefs.dart';

/// Checks it's really you: fingerprint, face, or the phone's PIN/pattern.
/// An interface so tests can swap in a fake through [create].
abstract class Authenticator {
  static Authenticator Function() create = _DeviceAuthenticator.new;

  /// Whether this phone can confirm it's you at all (a screen lock is set).
  Future<bool> isAvailable();

  /// Asks the phone to confirm; true when it did.
  Future<bool> confirm(String reason);
}

class _DeviceAuthenticator implements Authenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> confirm(String reason) async {
    try {
      // Not biometric-only: the phone's PIN or pattern works too.
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }
}

/// What happened when turning the lock on.
enum LockSetup { on, noScreenLock, cancelled }

/// Locks Inkleaf behind the phone's own fingerprint, face or PIN.
///
/// When on, the app starts locked, and locks again after being away for
/// more than [awayLimit]. [locked] drives the lock screen.
class AppLock with WidgetsBindingObserver {
  AppLock._();

  static final instance = AppLock._();

  static const awayLimit = Duration(seconds: 30);

  final locked = ValueNotifier<bool>(false);
  Authenticator _auth = Authenticator.create();
  DateTime? _leftAt;
  bool _confirming = false;
  bool _observing = false;

  bool get enabled => AppPrefs.instance.appLock;

  void init() {
    _auth = Authenticator.create();
    locked.value = enabled;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  Future<bool> _confirm(String reason) async {
    _confirming = true;
    try {
      return await _auth.confirm(reason);
    } finally {
      _confirming = false;
    }
  }

  Future<LockSetup> turnOn() async {
    if (!await _auth.isAvailable()) return LockSetup.noScreenLock;
    if (!await _confirm('Confirm it’s you to lock Inkleaf')) {
      return LockSetup.cancelled;
    }
    await AppPrefs.instance.setAppLock(true);
    return LockSetup.on;
  }

  /// True when the lock was turned off.
  Future<bool> turnOff() async {
    if (!await _confirm('Confirm it’s you to remove the lock')) return false;
    await AppPrefs.instance.setAppLock(false);
    locked.value = false;
    return true;
  }

  Future<void> unlock() async {
    if (!locked.value || _confirming) return;
    if (await _confirm('Unlock Inkleaf')) locked.value = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The fingerprint prompt itself sends the app to the background.
    if (!enabled || _confirming) return;
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final left = _leftAt;
        _leftAt = null;
        if (left != null && DateTime.now().difference(left) > awayLimit) {
          locked.value = true;
        }
      case _:
        break;
    }
  }
}
