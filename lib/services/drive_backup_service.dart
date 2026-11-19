import 'dart:convert';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'package:sqflite/sqflite.dart';

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
    final income = await db.query('income_entries');
    final incomePayments = await db.query('income_payments');
    final creditParties = await db.query('credit_parties');
    final creditTransactions = await db.query('credit_transactions');
    final cashSessions = await db.query('cash_sessions');
    final cashTransactions = await db.query('cash_transactions');
    final monthlyBudgets = await db.query('monthly_budgets');
    final categoryBudgets = await db.query('category_budgets');
    final recurringExpenses = await db.query('recurring_expenses');
    final appMeta = await db.query('app_meta');
    return {
      'format': 'billit-finance-sqlite-json',
      'version': 3,
      'createdAt': DateTime.now().toIso8601String(),
      'expenses': expenses,
      'employees': employees,
      'payroll_payments': payroll,
      'income_entries': income,
      'income_payments': incomePayments,
      'credit_parties': creditParties,
      'credit_transactions': creditTransactions,
      'cash_sessions': cashSessions,
      'cash_transactions': cashTransactions,
      'monthly_budgets': monthlyBudgets,
      'category_budgets': categoryBudgets,
      'recurring_expenses': recurringExpenses,
      'app_meta': appMeta,
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
    await DatabaseService.instance.setMetaValue('last_backup_at', DateTime.now().toIso8601String());
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
    // Preserve the current local books in Drive before any destructive restore.
    await createBackup();
    final api = await _api();
    final media = await api.files.get(fileId,
      downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final builder = BytesBuilder();
    await for (final chunk in media.stream) { builder.add(chunk); }
    final decoded = jsonDecode(utf8.decode(builder.takeBytes()));
    if (decoded is! Map) {
      throw const FormatException('This is not a valid Billit backup.');
    }
    final isFinanceBackup = decoded['format'] == 'billit-finance-sqlite-json' && (decoded['version'] == 1 || decoded['version'] == 2 || decoded['version'] == 3);
    final isLegacyBillitBackup = decoded['expenses'] is List && decoded['employees'] is List;
    if (!isFinanceBackup && !isLegacyBillitBackup) {
      throw const FormatException('This backup does not contain compatible Billit finance data.');
    }
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      await txn.delete('cash_transactions');
      await txn.delete('app_meta');
      await txn.delete('recurring_expenses');
      await txn.delete('category_budgets');
      await txn.delete('monthly_budgets');
      await txn.delete('cash_sessions');
      await txn.delete('credit_transactions');
      await txn.delete('credit_parties');
      await txn.delete('income_payments');
      await txn.delete('income_entries');
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
      if (isFinanceBackup) {
        for (final raw in (decoded['income_entries'] as List? ?? const [])) { await txn.insert('income_entries', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['income_payments'] as List? ?? const [])) { await txn.insert('income_payments', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['credit_parties'] as List? ?? const [])) { await txn.insert('credit_parties', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['credit_transactions'] as List? ?? const [])) { await txn.insert('credit_transactions', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['cash_sessions'] as List? ?? const [])) { await txn.insert('cash_sessions', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['cash_transactions'] as List? ?? const [])) { await txn.insert('cash_transactions', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['monthly_budgets'] as List? ?? const [])) { await txn.insert('monthly_budgets', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['category_budgets'] as List? ?? const [])) { await txn.insert('category_budgets', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['recurring_expenses'] as List? ?? const [])) { await txn.insert('recurring_expenses', Map<String, Object?>.from(raw as Map)); }
        for (final raw in (decoded['app_meta'] as List? ?? const [])) { await txn.insert('app_meta', Map<String, Object?>.from(raw as Map)); }
      } else if (isLegacyBillitBackup) {
        // Convert Billit's existing sales into income records while preserving
        // the original sale ID for idempotent future imports.
        for (final raw in (decoded['sales'] as List? ?? const [])) {
          final sale = Map<String, Object?>.from(raw as Map);
          final saleId = (sale['id'] ?? '').toString();
          final amount = (sale['totalAmount'] as num?)?.toDouble() ?? 0;
          if (saleId.isEmpty || amount <= 0) continue;
          final incomeId = await txn.insert('income_entries', {
            'date': sale['date'] ?? DateTime.now().toIso8601String(),
            'amount': amount,
            'cost_amount': (sale['totalCost'] as num?)?.toDouble() ?? 0,
            'description': 'Billit sale ' + saleId + ((sale['customerName'] as String?)?.isNotEmpty == true ? ' • ' + (sale['customerName'] as String) : ''),
            'source': 'billit_import',
            'external_id': 'billit:' + saleId,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (incomeId > 0) {
            final method = switch ((sale['payment'] ?? 'cash').toString()) { 'upi' => 'upi', 'card' => 'card', _ => 'cash' };
            await txn.insert('income_payments', {'income_id': incomeId, 'date': sale['date'] ?? DateTime.now().toIso8601String(), 'method': method, 'amount': amount});
          }
        }
      }
    });
  }
}
