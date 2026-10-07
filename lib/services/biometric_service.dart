import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _keyUsername = 'bio_saved_username_hcp';
  static const String _keyPassword = 'bio_saved_password_hcp';
  static const String _keyPosition = 'bio_saved_position_hcp';
  static const String _keyFullName = 'bio_saved_fullname_hcp';
  static const String _keyEnabled = 'bio_enabled_hcp';

  /// Check if device supports biometric authentication
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
      
      return (canAuthenticateWithBiometrics || isSupported) &&
          (availableBiometrics.isNotEmpty || isSupported);
    } catch (e) {
      return false;
    }
  }

  /// Get list of available biometric hardware types (Face ID, Touch ID, Fingerprint, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Trigger biometric prompt
  static Future<bool> authenticate({String? customReason}) async {
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: customReason ?? 'Authenticate to log in to HCP Profiling',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      AppLogger.w('BiometricService', 'Biometric auth error: $e');
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Save user credentials and detected position locally in hardware-backed secure storage
  static Future<void> saveCredentials(
    String username,
    String password, {
    String? position,
    String? fullName,
  }) async {
    // Write credentials to hardware-backed Keystore/Keychain
    await _secureStorage.write(key: _keyUsername, value: username.trim());
    await _secureStorage.write(key: _keyPassword, value: password);
    if (position != null && position.isNotEmpty) {
      await _secureStorage.write(key: _keyPosition, value: position);
    }
    if (fullName != null && fullName.isNotEmpty) {
      await _secureStorage.write(key: _keyFullName, value: fullName);
    }
    await _secureStorage.write(key: _keyEnabled, value: 'true');

    // Scrub any legacy unencrypted SharedPreferences keys
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyPassword);
      await prefs.remove(_keyPosition);
      await prefs.remove(_keyFullName);
      await prefs.remove(_keyEnabled);
    } catch (_) {}
  }

  /// Get saved credentials from hardware-backed secure storage
  static Future<Map<String, String>?> getSavedCredentials() async {
    // 1. Attempt read from hardware-backed secure storage
    String? isEnabledStr = await _secureStorage.read(key: _keyEnabled);
    String? username = await _secureStorage.read(key: _keyUsername);
    String? password = await _secureStorage.read(key: _keyPassword);
    String? position = await _secureStorage.read(key: _keyPosition);
    String? fullName = await _secureStorage.read(key: _keyFullName);

    // 2. Automatic migration from legacy unencrypted SharedPreferences if exists
    if ((username == null || password == null) && isEnabledStr == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final legacyEnabled = prefs.getBool(_keyEnabled) ?? false;
        final legacyUser = prefs.getString(_keyUsername);
        final legacyPass = prefs.getString(_keyPassword);
        final legacyPos = prefs.getString(_keyPosition);
        final legacyName = prefs.getString(_keyFullName);

        if (legacyEnabled && legacyUser != null && legacyPass != null) {
          // Migrate to secure storage immediately
          await saveCredentials(
            legacyUser,
            legacyPass,
            position: legacyPos,
            fullName: legacyName,
          );
          return {
            'username': legacyUser,
            'password': legacyPass,
            if (legacyPos != null) 'position': legacyPos,
            if (legacyName != null) 'full_name': legacyName,
          };
        }
      } catch (_) {}
    }

    final bool isEnabled = isEnabledStr == 'true';
    if (isEnabled && username != null && username.isNotEmpty && password != null && password.isNotEmpty) {
      return {
        'username': username,
        'password': password,
        if (position != null) 'position': position,
        if (fullName != null) 'full_name': fullName,
      };
    }
    return null;
  }

  /// Get the email of the registered device owner
  static Future<String?> getEnrolledOwnerEmail() async {
    final creds = await getSavedCredentials();
    return creds?['username'];
  }

  /// Checks if the typed username matches the enrolled device owner.
  /// If a different username is entered, biometric login is blocked to prevent account breach.
  static Future<bool> isUsernameAllowedForBiometric(String? typedUsername) async {
    final credentials = await getSavedCredentials();
    if (credentials == null) return false;
    final enrolledOwner = credentials['username']?.trim().toLowerCase();
    if (enrolledOwner == null || enrolledOwner.isEmpty) return false;

    if (typedUsername == null || typedUsername.trim().isEmpty) {
      return true; // Can auto-fill and authenticate as enrolled owner
    }

    return typedUsername.trim().toLowerCase() == enrolledOwner;
  }

  /// Clear/Unlink saved biometric credentials completely
  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _keyUsername);
    await _secureStorage.delete(key: _keyPassword);
    await _secureStorage.delete(key: _keyPosition);
    await _secureStorage.delete(key: _keyFullName);
    await _secureStorage.delete(key: _keyEnabled);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyPassword);
      await prefs.remove(_keyPosition);
      await prefs.remove(_keyFullName);
      await prefs.remove(_keyEnabled);
    } catch (_) {}
  }
}
