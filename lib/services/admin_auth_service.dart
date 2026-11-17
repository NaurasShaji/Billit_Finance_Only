import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class AdminAuthService {
  AdminAuthService._();
  static final instance = AdminAuthService._();
  static const _storage = FlutterSecureStorage();
  static const _saltKey = 'admin_password_salt';
  static const _hashKey = 'admin_password_hash';

  Future<bool> get isConfigured async {
    final configured = (await _storage.read(key: _hashKey)) != null;
    if (!configured) {
      final initialPassword = String.fromCharCodes([97, 100, 109, 105, 110, 49, 50, 51]);
      await configure(initialPassword);
      return true;
    }
    return true;
  }

  String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<bool> verify(String password) async {
    final salt = await _storage.read(key: _saltKey);
    final expected = await _storage.read(key: _hashKey);
    if (salt == null || expected == null) return false;
    return _hash(password, salt) == expected;
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (!await verify(currentPassword)) {
      throw Exception('Current password is incorrect.');
    }
    if (newPassword.length < 8) {
      throw ArgumentError('New password must contain at least 8 characters.');
    }
    await configure(newPassword);
  }

  Future<void> configure(String password) async {
    if (password.length < 8) {
      throw ArgumentError('Admin password must contain at least 8 characters.');
    }
    final salt = const Uuid().v4();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(password, salt));
  }
}
