import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Helper class for PIN encryption and verification
/// Uses SHA-256 hashing for secure PIN storage
class EncryptionHelper {
  /// Encrypts a PIN using SHA-256 hash
  /// Returns base64-encoded hash string
  static String encryptPin(String pin) {
    if (pin.length != 6 || !_isNumeric(pin)) {
      throw ArgumentError('PIN must be exactly 6 digits');
    }
    
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// Verifies if provided PIN matches the encrypted PIN
  /// Returns true if PIN is correct, false otherwise
  static bool verifyPin(String inputPin, String encryptedPin) {
    try {
      final inputEncrypted = encryptPin(inputPin);
      return inputEncrypted == encryptedPin;
    } catch (e) {
      return false;
    }
  }

  /// Validates if a string contains only numeric characters
  static bool _isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  /// Validates PIN format (6 digits)
  static bool isValidPin(String pin) {
    return pin.length == 6 && _isNumeric(pin);
  }
}
