import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

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

  /// Trigger biometric prompt strictly bound to registered owner
  static Future<bool> authenticate({String? customReason}) async {
    try {
      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      final credentials = await getSavedCredentials();
      final owner = credentials?['username'] ?? 'registered device owner';

      return await _auth.authenticate(
        localizedReason: customReason ?? 'Authenticate as $owner to log in to PIMS HCP',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print('Biometric auth error: $e');
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Save user credentials and detected position locally for biometric login (locked to this owner)
  static Future<void> saveCredentials(
    String username,
    String password, {
    String? position,
    String? fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username.trim());
    await prefs.setString(_keyPassword, password);
    if (position != null && position.isNotEmpty) {
      await prefs.setString(_keyPosition, position);
    }
    if (fullName != null && fullName.isNotEmpty) {
      await prefs.setString(_keyFullName, fullName);
    }
    await prefs.setBool(_keyEnabled, true);
  }

  /// Get saved credentials if biometric login is enabled
  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool(_keyEnabled) ?? false;
    final String? username = prefs.getString(_keyUsername);
    final String? password = prefs.getString(_keyPassword);
    final String? position = prefs.getString(_keyPosition);
    final String? fullName = prefs.getString(_keyFullName);

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

  /// Clear saved credentials
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyPassword);
    await prefs.remove(_keyPosition);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEnabled);
  }
}
