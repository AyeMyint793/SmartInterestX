import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App lock. Everything here is stored on THIS phone only (never in the cloud):
/// the PIN is saved as a salted hash, so the real PIN is not stored anywhere.
class SecurityProvider extends ChangeNotifier {
  static const List<String> autoLockOptions = [
    'When you leave the app',
    'After 1 minute',
    'After 5 minutes',
  ];

  SharedPreferences? _prefs;
  final LocalAuthentication _auth = LocalAuthentication();

  bool loaded = false;
  bool pinEnabled = false;
  bool biometricEnabled = false;
  String autoLock = autoLockOptions.first;
  bool locked = false;

  DateTime? _leftAt;
  int _guards = 0;

  /// Reads the saved settings. Call once when the app starts.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    pinEnabled = prefs.getString('pin_hash') != null;
    biometricEnabled = pinEnabled && (prefs.getBool('biometric') ?? false);
    autoLock = prefs.getString('auto_lock') ?? autoLockOptions.first;
    locked = pinEnabled; // locked when the app opens
    loaded = true;
    notifyListeners();
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
    await _prefs?.setString('pin_salt', salt);
    await _prefs?.setString('pin_hash', _hash(pin, salt));
    pinEnabled = true;
    locked = false;
    notifyListeners();
  }

  bool verifyPin(String pin) {
    final salt = _prefs?.getString('pin_salt');
    final hash = _prefs?.getString('pin_hash');
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  /// Turns the lock off completely (also used when logging out).
  Future<void> removePin() async {
    await _prefs?.remove('pin_hash');
    await _prefs?.remove('pin_salt');
    await _prefs?.remove('biometric');
    pinEnabled = false;
    biometricEnabled = false;
    locked = false;
    notifyListeners();
  }

  Future<void> setAutoLock(String value) async {
    autoLock = value;
    await _prefs?.setString('auto_lock', value);
    notifyListeners();
  }

  Future<void> setBiometric(bool value) async {
    biometricEnabled = value;
    await _prefs?.setBool('biometric', value);
    notifyListeners();
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  // ---- Biometrics ----
  Future<bool> biometricAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await guard(
        () => _auth.authenticate(
          localizedReason: reason,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ---- Auto-lock ----

  /// Wrap anything that leaves the app briefly (gallery, share sheet) so the
  /// app does not lock itself when you come back:
  /// `await security.guard(() => picker.pickImage(...))`
  Future<T> guard<T>(Future<T> Function() action) async {
    _guards++;
    try {
      return await action();
    } finally {
      _guards--;
      _leftAt = null;
    }
  }

  void appPaused() {
    if (pinEnabled && _guards == 0) _leftAt = DateTime.now();
  }

  void appResumed() {
    if (!pinEnabled || locked) return;
    final left = _leftAt;
    _leftAt = null;
    if (left == null) return;

    Duration limit = Duration.zero;
    if (autoLock == autoLockOptions[1]) limit = const Duration(minutes: 1);
    if (autoLock == autoLockOptions[2]) limit = const Duration(minutes: 5);

    if (DateTime.now().difference(left) >= limit) {
      locked = true;
      notifyListeners();
    }
  }
}
