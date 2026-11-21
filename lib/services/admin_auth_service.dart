import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class AdminAuthService {
  AdminAuthService._();
  static final instance = AdminAuthService._();
  static const _storage = FlutterSecureStorage();
  static const _saltKey = 'admin_password_salt';
  static const _hashKey = 'admin_password_hash';
  static const _mustChangeKey = 'admin_password_change_required';
  static const _sessionKey = 'admin_authenticated_session';
  final ValueNotifier<bool> sessionActive = ValueNotifier<bool>(false);
  // Shared initial installer password. The owner must replace it before entry.
  static const defaultAdminPassword = 'Billit@Shop#Start2026!Secure';

  Future<bool> get isConfigured async {
    final configured = (await _storage.read(key: _hashKey)) != null;
    if (!configured) {
      await _writePassword(defaultAdminPassword, requireChange: true);
    } else if (await _storage.read(key: _mustChangeKey) == null) {
      // Migrate existing installations that still use the old admin123 default.
      final isLegacyDefault = await verify('admin123');
      await _storage.write(
        key: _mustChangeKey,
        value: isLegacyDefault ? 'true' : 'false',
      );
    }
    return true;
  }

  Future<bool> get mustChangePassword async =>
      (await _storage.read(key: _mustChangeKey)) == 'true';

  /// A session remains active across app restarts until the user logs out.
  Future<bool> get hasActiveSession async =>
      (await _storage.read(key: _sessionKey)) == 'true';

  Future<void> setSessionActive(bool active) async {
    if (active) {
      await _storage.write(key: _sessionKey, value: 'true');
    } else {
      await _storage.delete(key: _sessionKey);
    }
    sessionActive.value = active;
  }

  static const securityQuestions = <String, String>{
    'school': 'What was the name of your first school?',
    'nickname': 'What was your childhood nickname?',
    'pet': 'What was the name of your first pet?',
    'city': 'In which city did you grow up?',
    'teacher': 'What was the surname of a favourite teacher?',
    'friend': 'What was the first name of a childhood friend?',
  };
  static const _recoveryKey = 'admin_security_recovery_v1';

  String _answerHash(String answer, String salt) =>
      sha256.convert(utf8.encode('$salt:${answer.trim().toLowerCase()}')).toString();

  Future<bool> get hasRecoveryQuestions async =>
      (await _storage.read(key: _recoveryKey)) != null;

  Future<void> saveRecoveryAnswers(
    String currentPassword,
    Map<String, String> answers,
  ) async {
    if (!await verify(currentPassword)) {
      throw Exception('Current admin password is incorrect.');
    }
    if (answers.length != 1 || answers.values.any((a) => a.trim().length < 3)) {
      throw ArgumentError('Choose one security question and provide an answer of at least 3 characters.');
    }
    final entries = <String, Map<String, String>>{};
    for (final entry in answers.entries) {
      if (!securityQuestions.containsKey(entry.key)) {
        throw ArgumentError('Invalid security question.');
      }
      final salt = const Uuid().v4();
      entries[entry.key] = {'salt': salt, 'hash': _answerHash(entry.value, salt)};
    }
    await _storage.write(key: _recoveryKey, value: jsonEncode(entries));
  }

  Future<List<String>> getRecoveryQuestionIds() async {
    final raw = await _storage.read(key: _recoveryKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.keys.toList();
  }

  Future<bool> verifyRecoveryAnswers(Map<String, String> answers) async {
    final raw = await _storage.read(key: _recoveryKey);
    if (raw == null) return false;
    final stored = jsonDecode(raw) as Map<String, dynamic>;
    if (answers.length != stored.length) return false;
    for (final entry in stored.entries) {
      final answer = answers[entry.key];
      if (answer == null) return false;
      final record = entry.value as Map<String, dynamic>;
      if (_answerHash(answer, record['salt'] as String) != record['hash']) return false;
    }
    return true;
  }

  Future<void> resetPasswordWithRecovery(
    Map<String, String> answers,
    String newPassword,
  ) async {
    if (!await verifyRecoveryAnswers(answers)) {
      throw Exception('Security answers do not match.');
    }
    await _writePassword(newPassword, requireChange: false);
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
    await _writePassword(password, requireChange: false);
  }

  Future<void> _writePassword(
    String password, {
    required bool requireChange,
  }) async {
    final salt = const Uuid().v4();
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(password, salt));
    await _storage.write(
      key: _mustChangeKey,
      value: requireChange ? 'true' : 'false',
    );
  }
}
