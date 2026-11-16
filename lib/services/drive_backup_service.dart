import 'dart:convert';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'database_service.dart';

class _AuthClient extends http.BaseClient {
  _AuthClient(this.headers);
  final Map<String, String> headers;
  final _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }
  @override
  void close() { _inner.close(); super.close(); }
}

class DriveBackup {
  const DriveBackup({required this.id, required this.name, this.modifiedTime});
  final String id;
  final String name;
  final DateTime? modifiedTime;
}

class DriveBackupService {
  DriveBackupService._();
  static final instance = DriveBackupService._();
  final GoogleSignIn _signIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  static const _folderName = 'Billit';

  Future<GoogleSignInAccount?> signIn() async {
    final existing = await _signIn.signInSilently();
    return existing ?? await _signIn.signIn();
  }

  Future<drive.DriveApi> _api() async {
    final user = _signIn.currentUser ?? await signIn();
    if (user == null) throw StateError('Google Drive sign-in was cancelled.');
    return drive.DriveApi(_AuthClient(await user.authHeaders));
  }

  Future<String> _folder(drive.DriveApi api) async {
    final found = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$_folderName' and trashed=false",
      spaces: 'drive', pageSize: 1, $fields: 'files(id)',
    );
    if (found.files?.isNotEmpty == true) return found.files!.first.id!;
    final created = await api.files.create(drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder');
    return created.id!;
  }

  Future<Map<String, dynamic>> exportDatabase() async {
    final db = await DatabaseService.instance.database;
    final expenses = await db.query('expenses');
    final employees = await db.query('employees');
    final payroll = await db.query('payroll_payments');
    return {
      'format': 'billit-finance-sqlite-json',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'expenses': expenses,
      'employees': employees,
      'payroll_payments': payroll,
    };
  }

  Future<void> createBackup() async {
    final api = await _api();
    final folderId = await _folder(api);
    final json = await exportDatabase();
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
    final media = drive.Media(Stream<List<int>>.value(bytes), bytes.length);
    await api.files.create(
      drive.File()
        ..name = 'billit_finance_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json'
        ..mimeType = 'application/json'
        ..parents = [folderId],
      uploadMedia: media,
      $fields: 'id',
    );
  }

  Future<List<DriveBackup>> listBackups() async {
    final api = await _api();
    final folderId = await _folder(api);
    final result = await api.files.list(
      q: "'$folderId' in parents and mimeType='application/json' and trashed=false",
      orderBy: 'modifiedTime desc', pageSize: 50, spaces: 'drive',
      $fields: 'files(id,name,modifiedTime)',
    );
    return (result.files ?? []).where((f) => f.id != null && f.name != null)
      .map((f) => DriveBackup(id: f.id!, name: f.name!, modifiedTime: f.modifiedTime))
      .toList();
  }

  Future<void> restore(String fileId) async {
    final api = await _api();
    final media = await api.files.get(fileId,
      downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final builder = BytesBuilder();
    await for (final chunk in media.stream) { builder.add(chunk); }
    final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
    if (decoded is! Map) {
      throw const FormatException('This is not a valid Billit backup.');
    }
    final isFinanceBackup = decoded['format'] == 'billit-finance-sqlite-json' && decoded['version'] == 1;
    final isLegacyBillitBackup = decoded['expenses'] is List && decoded['employees'] is List;
    if (!isFinanceBackup && !isLegacyBillitBackup) {
      throw const FormatException('This backup does not contain compatible Billit finance data.');
    }
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      await txn.delete('payroll_payments');
      await txn.delete('expenses');
      await txn.delete('employees');
      for (final raw in (decoded['employees'] as List? ?? const [])) {
        final row = Map<String, Object?>.from(raw as Map);
        if (isLegacyBillitBackup) {
          await txn.insert('employees', {
            'name': row['name'] ?? '',
            'type': row['type'] == 'monthly' ? 'monthly' : 'daily',
            'wage': (row['wage'] as num?)?.toDouble() ?? 0,
            'active': 1,
          });
        } else {
          await txn.insert('employees', row);
        }
      }
      for (final raw in (decoded['expenses'] as List? ?? const [])) {
        final row = Map<String, Object?>.from(raw as Map);
        if (isLegacyBillitBackup) {
          await txn.insert('expenses', {
            'date': row['date'] ?? DateTime.now().toIso8601String(),
            'category': row['category'] ?? 'Miscellaneous',
            'amount': (row['amount'] as num?)?.toDouble() ?? 0,
            'description': row['description'] ?? '',
          });
        } else {
          await txn.insert('expenses', row);
        }
      }
      for (final raw in (decoded['payroll_payments'] as List? ?? const [])) {
        await txn.insert('payroll_payments', Map<String, Object?>.from(raw as Map));
      }
    });
  }
}
