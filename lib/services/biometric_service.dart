import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger_service.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Check if the device supports biometrics and has them Enrolled
  Future<bool> get isDeviceSupported async {
    // Biometrics are tricky on web often leading to MissingPluginException if not configured
    // For this MVP, we will disable biometrics on Web to ensure stability.
    if (kIsWeb) return false;

    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      // Catch PlatformException and MissingPluginException
      logger.error("Error checking device support", error: e);
      return false;
    }
  }

  /// Check if the user has enabled "Remember Me"
  Future<bool> get isBiometricEnabled async {
    if (kIsWeb) return false;
    try {
      final val = await _storage.read(key: _biometricEnabledKey);
      return val == 'true';
    } catch (e) {
      logger.error("Error reading biometric preference", error: e);
      return false;
    }
  }

  /// Enable or disable biometric login preference
  Future<void> setBiometricEnabled(bool enabled) async {
    if (kIsWeb) return; // No-op on web
    try {
      await _storage.write(
          key: _biometricEnabledKey, value: enabled.toString());
      logger.info("Biometric preference set to: $enabled");
    } catch (e) {
      logger.error("Error setting biometric preference", error: e);
    }
  }

  /// Authenticate the user
  Future<bool> authenticate() async {
    if (kIsWeb) return true; // Bypass on web if it ever gets here

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to access Nerd Herd',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow passcode fallback
        ),
      );
      return didAuthenticate;
    } catch (e) {
      logger.error("Authentication failed", error: e);
      return false;
    }
  }
}

final biometricService = BiometricService();
