import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static const MethodChannel _channel = MethodChannel(
    'com.vitap.vitap_nexus_app/biometrics',
  );

  /// Checks whether fingerprint, face unlock, or device credential authentication
  /// is available on the current device.
  static Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isBiometricAvailable');
      return result == true;
    } catch (e) {
      debugPrint('BiometricService.isBiometricAvailable error: $e');
      return false;
    }
  }

  /// Triggers the native OS biometric / device credential prompt.
  static Future<bool> authenticate({
    String title = 'Biometric Authentication',
    String subtitle = 'Verify your identity to continue',
  }) async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('authenticate', {
        'title': title,
        'subtitle': subtitle,
      });
      return result == true;
    } catch (e) {
      debugPrint('BiometricService.authenticate error: $e');
      return false;
    }
  }
}
