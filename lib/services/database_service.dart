import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/finance_models.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();
  Database? _db;

  /// Incremented after every write so open screens can refresh themselves.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void notifyChanged() => revision.value++;
  Future<T> _write<T>(Future<T> Function(Database db) op) async {
    final result = await op(await database);
    notifyChanged();
    return result;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'billit_finance.db'),
      version: 5,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createBaseTables(db);
        await _createFinanceTables(db);
        await _createBudgetTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE employees ADD COLUMN attendance INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE employees ADD COLUMN salary_paid INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) await _createFinanceTables(db);
        if (oldVersion < 4) await db.execute('ALTER TABLE income_entries ADD COLUMN cost_amount REAL NOT NULL DEFAULT 0 CHECK(cost_amount >= 0)');
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE expenses ADD COLUMN receipt_path TEXT');
          await _createBudgetTables(db);
        }
      },
    );
    return _db!;
  }

  Future<void> _createBaseTables(DatabaseExecutor db) async {
    await db.execute("""CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, category TEXT NOT NULL,
      amount REAL NOT NULL CHECK(amount > 0), description TEXT NOT NULL DEFAULT '')""");
    await db.execute("""CREATE TABLE employees (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('daily','monthly')), wage REAL NOT NULL CHECK(wage > 0),
      active INTEGER NOT NULL DEFAULT 1, attendance INTEGER NOT NULL DEFAULT 0, salary_paid INTEGER NOT NULL DEFAULT 0)""");
    await db.execute("""CREATE TABLE payroll_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, employee_id INTEGER NOT NULL REFERENCES employees(id),
      date TEXT NOT NULL, period TEXT NOT NULL, amount REAL NOT NULL CHECK(amount > 0),
      type TEXT NOT NULL, note TEXT NOT NULL DEFAULT '')""");
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX idx_payroll_date ON payroll_payments(date)');
  }

  Future<void> _createFinanceTables(DatabaseExecutor db) async {
    await db.execute("""CREATE TABLE income_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, amount REAL NOT NULL CHECK(amount > 0),
      description TEXT NOT NULL DEFAULT '', cost_amount REAL NOT NULL DEFAULT 0 CHECK(cost_amount >= 0), source TEXT NOT NULL DEFAULT 'manual',
      external_id TEXT UNIQUE)""");
    await db.execute("""CREATE TABLE income_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, income_id INTEGER NOT NULL REFERENCES income_entries(id) ON DELETE CASCADE,
      date TEXT NOT NULL, method TEXT NOT NULL CHECK(method IN ('cash','upi','card','bank','other')),
      amount REAL NOT NULL CHECK(amount > 0))""");
    await db.execute("""CREATE TABLE credit_parties (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL CHECK(type IN ('customer','supplier')),
      phone TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '')""");
    await db.execute("""CREATE TABLE credit_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, party_id INTEGER NOT NULL REFERENCES credit_parties(id),
      date TEXT NOT NULL, type TEXT NOT NULL CHECK(type IN ('credit_sale','credit_purchase','payment_received','payment_made','adjustment')),
      amount REAL NOT NULL CHECK(amount > 0), due_date TEXT, note TEXT NOT NULL DEFAULT '',
      income_id INTEGER REFERENCES income_entries(id))""");
    await db.execute("""CREATE TABLE cash_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL UNIQUE,
      opening_balance REAL NOT NULL CHECK(opening_balance >= 0), closing_balance REAL,
      status TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed')))""");
    await db.execute("""CREATE TABLE cash_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER NOT NULL REFERENCES cash_sessions(id) ON DELETE CASCADE,
      date TEXT NOT NULL, direction TEXT NOT NULL CHECK(direction IN ('in','out')),
      method TEXT NOT NULL CHECK(method IN ('cash','upi','card','bank')),
      amount REAL NOT NULL CHECK(amount > 0), category TEXT NOT NULL DEFAULT '', note TEXT NOT NULL DEFAULT '')""");
    await db.execute('CREATE INDEX idx_income_date ON income_entries(date)');
    await db.execute('CREATE INDEX idx_credit_party ON credit_transactions(party_id, date)');
    await db.execute('CREATE INDEX idx_cash_session ON cash_transactions(session_id, date)');
  }


  Future<void> _createBudgetTables(DatabaseExecutor db) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS monthly_budgets (month_key TEXT PRIMARY KEY, limit_amount REAL NOT NULL CHECK(limit_amount > 0))""");
    await db.execute("""CREATE TABLE IF NOT EXISTS category_budgets (
      id INTEGER PRIMARY KEY AUTOINCREMENT, month_key TEXT NOT NULL,
      category TEXT NOT NULL, limit_amount REAL NOT NULL CHECK(limit_amount > 0),
      UNIQUE(month_key, category))""");
    await db.execute("""CREATE TABLE IF NOT EXISTS recurring_expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL,
      amount REAL NOT NULL CHECK(amount > 0), description TEXT NOT NULL DEFAULT '',
      day_of_month INTEGER NOT NULL CHECK(day_of_month BETWEEN 1 AND 31),
      active INTEGER NOT NULL DEFAULT 1, last_generated_month TEXT)""");
  }

  Future<double?> totalMonthlyBudget(String monthKey) async {
    final rows = await (await database).query('monthly_budgets', where: 'month_key = ?', whereArgs: [monthKey], limit: 1);
    return rows.isEmpty ? null : (rows.first['limit_amount'] as num).toDouble();
  }
  Future<void> saveMonthlyBudget(String monthKey, double limit) async {
    await _write((db) => db.insert('monthly_budgets', {'month_key': monthKey, 'limit_amount': limit}, conflictAlgorithm: ConflictAlgorithm.replace));
  }
  Future<double?> monthlyBudget(String monthKey) async {
    final rows = await (await database).query('category_budgets', columns: ['SUM(limit_amount) AS total'], where: 'month_key = ?', whereArgs: [monthKey]);
    final value = rows.first['total'] as num?;
    return value?.toDouble();
  }
  Future<List<CategoryBudget>> categoryBudgets(String monthKey) async =>
      (await (await database).query('category_budgets', where: 'month_key = ?', whereArgs: [monthKey], orderBy: 'category')).map(CategoryBudget.fromMap).toList();
  Future<void> saveCategoryBudget(CategoryBudget budget) async {
    await _write((db) => db.insert('category_budgets', budget.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.replace));
  }
  Future<List<RecurringExpense>> recurringExpenses() async =>
      (await (await database).query('recurring_expenses', orderBy: 'active DESC, category')).map(RecurringExpense.fromMap).toList();
  Future<int> saveRecurringExpense(RecurringExpense item) => _write((db) async {
    final values = item.toMap()..remove('id');
    if (item.id == null) return db.insert('recurring_expenses', values);
    return db.update('recurring_expenses', values, where: 'id = ?', whereArgs: [item.id]);
  });
  Future<int> deleteRecurringExpense(int id) => _write((db) => db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]));
  Future<void> generateRecurringExpenses(DateTime now) async {
    final db = await database;
    final monthKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    await db.transaction((txn) async {
      final templates = await txn.query('recurring_expenses', where: 'active = 1 AND (last_generated_month IS NULL OR last_generated_month != ?)', whereArgs: [monthKey]);
      for (final raw in templates) {
        final item = RecurringExpense.fromMap(raw);
        final day = item.dayOfMonth.clamp(1, DateTime(now.year, now.month + 1, 0).day);
        await txn.insert('expenses', {'date': DateTime(now.year, now.month, day).toIso8601String(), 'category': item.category, 'amount': item.amount, 'description': item.description});
        await txn.update('recurring_expenses', {'last_generated_month': monthKey}, where: 'id = ?', whereArgs: [item.id]);
      }
    });
    notifyChanged();
  }

  Future<int> addExpense(ExpenseRecord e) => _write((db) => db.insert('expenses', e.toMap()..remove('id')));
  Future<int> updateExpense(ExpenseRecord e) => _write((db) => db.update('expenses', e.toMap()..remove('id'), where: 'id = ?', whereArgs: [e.id]));
  Future<int> deleteExpense(int id) => _write((db) => db.delete('expenses', where: 'id = ?', whereArgs: [id]));
  Future<List<ExpenseRecord>> expenses({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query('expenses', where: start == null ? null : 'date >= ? AND date < ?', whereArgs: start == null ? null : [start.toIso8601String(), end!.toIso8601String()], orderBy: 'date DESC');
    return rows.map(ExpenseRecord.fromMap).toList();
  }
  Future<int> addEmployee(EmployeeRecord e) => _write((db) => db.insert('employees', e.toMap()..remove('id')));
  Future<int> updateEmployee(EmployeeRecord e) => _write((db) => db.update('employees', e.toMap()..remove('id'), where: 'id = ?', whereArgs: [e.id]));
  Future<int> archiveEmployee(int id) => _write((db) => db.update('employees', {'active': 0}, where: 'id = ?', whereArgs: [id]));
  Future<List<EmployeeRecord>> employees() async => (await (await database).query('employees', where: 'active = 1', orderBy: 'name')).map(EmployeeRecord.fromMap).toList();
  Future<int> addPayroll(PayrollPayment e) => _write((db) => db.insert('payroll_payments', e.toMap()..remove('id')));
  Future<List<PayrollPayment>> payroll({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query('payroll_payments', where: start == null ? null : 'date >= ? AND date < ?', whereArgs: start == null ? null : [start.toIso8601String(), end!.toIso8601String()], orderBy: 'date DESC');
    return rows.map(PayrollPayment.fromMap).toList();
  }

  Future<int> addIncome(IncomeRecord entry, {List<IncomePayment> payments = const []}) async {
    final db = await database;
    final newId = await db.transaction((txn) async {
      final id = await txn.insert('income_entries', entry.toMap()..remove('id'));
      final paid = payments.fold<double>(0, (sum, p) => sum + p.amount);
      if (paid - entry.amount > 0.005) throw ArgumentError('Payments cannot exceed the sale total.');
      for (final payment in payments) {
        await txn.insert('income_payments', payment.toMap()..remove('id')..['income_id'] = id);
      }
      return id;
    });
    notifyChanged();
    return newId;
  }
  Future<List<IncomeRecord>> income({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query('income_entries', where: start == null ? null : 'date >= ? AND date < ?', whereArgs: start == null ? null : [start.toIso8601String(), end!.toIso8601String()], orderBy: 'date DESC');
    return rows.map(IncomeRecord.fromMap).toList();
  }
  Future<List<IncomePayment>> incomePayments(int incomeId) async => (await (await database).query('income_payments', where: 'income_id = ?', whereArgs: [incomeId], orderBy: 'date')).map(IncomePayment.fromMap).toList();
  Future<double> incomeCollected({DateTime? start, DateTime? end}) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(p.amount),0) total FROM income_payments p WHERE (? IS NULL OR p.date >= ?) AND (? IS NULL OR p.date < ?)', [start?.toIso8601String(), start?.toIso8601String(), end?.toIso8601String(), end?.toIso8601String()]);
    return (result.first['total'] as num).toDouble();
  }
  /// Amount collected so far for each sale, keyed by income id.
  Future<Map<int, double>> incomePaidTotals() async {
    final rows = await (await database).rawQuery('SELECT income_id, COALESCE(SUM(amount),0) paid FROM income_payments GROUP BY income_id');
    return {for (final row in rows) row['income_id'] as int: (row['paid'] as num).toDouble()};
  }
  Future<int> addCreditParty(CreditParty party) => _write((db) => db.insert('credit_parties', party.toMap()..remove('id')));
  Future<List<CreditParty>> creditParties({String? type}) async => (await (await database).query('credit_parties', where: type == null ? null : 'type = ?', whereArgs: type == null ? null : [type], orderBy: 'name')).map(CreditParty.fromMap).toList();
  Future<int> addCreditTransaction(CreditTransaction entry) => _write((db) => db.insert('credit_transactions', entry.toMap()..remove('id')));
  Future<List<CreditTransaction>> creditTransactions(int partyId) async => (await (await database).query('credit_transactions', where: 'party_id = ?', whereArgs: [partyId], orderBy: 'date DESC')).map(CreditTransaction.fromMap).toList();
  Future<List<Map<String, Object?>>> creditBalances() async {
    return (await (await database).rawQuery("""SELECT p.*, COALESCE(SUM(CASE
      WHEN t.type IN ('credit_sale','credit_purchase','adjustment') THEN t.amount
      WHEN t.type IN ('payment_received','payment_made') THEN -t.amount
      ELSE 0 END),0) AS balance
      FROM credit_parties p LEFT JOIN credit_transactions t ON t.party_id=p.id
      GROUP BY p.id ORDER BY p.name"""));
  }

  Future<int> openCashSession(DateTime date, double opening) => _write((db) => db.insert('cash_sessions', {'date': DateTime(date.year,date.month,date.day).toIso8601String(), 'opening_balance': opening, 'status': 'open'}, conflictAlgorithm: ConflictAlgorithm.abort));
  Future<CashSession?> cashSession(DateTime date) async {
    final day = DateTime(date.year,date.month,date.day).toIso8601String();
    final rows = await (await database).query('cash_sessions', where: 'date = ?', whereArgs: [day], limit: 1);
    return rows.isEmpty ? null : CashSession.fromMap(rows.first);
  }
  Future<int> addCashTransaction(CashTransaction entry) async {
    final session = await cashSession(entry.date);
    if (session == null || session.status != 'open') throw StateError('Open the cash book for this date before adding transactions.');
    return _write((db) => db.insert('cash_transactions', entry.toMap()..remove('id')));
  }
  Future<List<CashTransaction>> cashTransactions(int sessionId) async => (await (await database).query('cash_transactions', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'date')).map(CashTransaction.fromMap).toList();
  Future<Map<String, double>> cashBalances(int sessionId) async {
    final rows = await (await database).rawQuery("SELECT method, SUM(CASE WHEN direction='in' THEN amount ELSE -amount END) net FROM cash_transactions WHERE session_id=? GROUP BY method", [sessionId]);
    return {for (final row in rows) row['method'] as String: (row['net'] as num).toDouble()};
  }
  Future<void> closeCashSession(int sessionId, double countedCash) async {
    final db = await database;
    final balances = await cashBalances(sessionId);
    final sessionRows = await db.query('cash_sessions', where: 'id = ?', whereArgs: [sessionId], limit: 1);
    if (sessionRows.isEmpty) throw StateError('Cash session not found.');
    final opening = (sessionRows.first['opening_balance'] as num).toDouble();
    final expectedCash = opening + (balances['cash'] ?? 0);
    if (countedCash < 0 || expectedCash.isNaN || !countedCash.isFinite) throw ArgumentError('Invalid closing cash amount.');
    await db.update('cash_sessions', {'closing_balance': countedCash, 'status': 'closed'}, where: 'id = ?', whereArgs: [sessionId]);
    notifyChanged();
  }
}
