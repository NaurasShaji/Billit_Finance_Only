import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/finance_models.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'billit_finance.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute("""CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL CHECK(amount > 0),
          description TEXT NOT NULL DEFAULT ''
        )""");
        await db.execute("""CREATE TABLE employees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('daily','monthly')),
          wage REAL NOT NULL CHECK(wage > 0),
          active INTEGER NOT NULL DEFAULT 1
        )""");
        await db.execute("""CREATE TABLE payroll_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL REFERENCES employees(id),
          date TEXT NOT NULL,
          period TEXT NOT NULL,
          amount REAL NOT NULL CHECK(amount > 0),
          type TEXT NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )""");
        await db.execute("""CREATE TABLE bank_accounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          bank_name TEXT NOT NULL,
          opening_balance REAL NOT NULL DEFAULT 0
        )""");
        await db.execute("""CREATE TABLE bank_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_id INTEGER NOT NULL REFERENCES bank_accounts(id),
          date TEXT NOT NULL,
          description TEXT NOT NULL,
          amount REAL NOT NULL CHECK(amount > 0),
          direction TEXT NOT NULL CHECK(direction IN ('credit','debit')),
          reference TEXT NOT NULL DEFAULT '',
          reconciled INTEGER NOT NULL DEFAULT 0
        )""");
        await db.execute("""CREATE TABLE stock_costs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          item TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit_cost REAL NOT NULL CHECK(unit_cost >= 0),
          kind TEXT NOT NULL CHECK(kind IN ('purchase','adjustment','opening')),
          note TEXT NOT NULL DEFAULT ''
        )""");
        await db.execute("""CREATE TABLE income_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          source TEXT NOT NULL,
          amount REAL NOT NULL CHECK(amount > 0),
          note TEXT NOT NULL DEFAULT ''
        )""");
        await db.execute("""CREATE TABLE reconciliation_links (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bank_transaction_id INTEGER NOT NULL UNIQUE
            REFERENCES bank_transactions(id) ON DELETE CASCADE,
          ledger_type TEXT NOT NULL,
          ledger_id INTEGER NOT NULL,
          matched_at TEXT NOT NULL
        )""");
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
        await db.execute('CREATE INDEX idx_payroll_date ON payroll_payments(date)');
        await db.execute('CREATE INDEX idx_bank_tx_date ON bank_transactions(date)');
        await db.execute('CREATE INDEX idx_stock_cost_date ON stock_costs(date)');
      },
    );
    return _db!;
  }

  Future<int> addExpense(ExpenseRecord e) async =>
      (await database).insert('expenses', e.toMap()..remove('id'));

  Future<int> updateExpense(ExpenseRecord e) async =>
      (await database).update('expenses', e.toMap()..remove('id'),
          where: 'id = ?', whereArgs: [e.id]);

  Future<int> deleteExpense(int id) async =>
      (await database).delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<List<ExpenseRecord>> expenses({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query(
      'expenses',
      where: start == null ? null : 'date >= ? AND date < ?',
      whereArgs: start == null
          ? null
          : [start.toIso8601String(), end!.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  Future<int> addEmployee(EmployeeRecord e) async =>
      (await database).insert('employees', e.toMap()..remove('id'));

  Future<List<EmployeeRecord>> employees() async =>
      (await (await database).query(
        'employees',
        where: 'active = 1',
        orderBy: 'name',
      )).map(EmployeeRecord.fromMap).toList();

  Future<int> addPayroll(PayrollPayment e) async =>
      (await database).insert('payroll_payments', e.toMap()..remove('id'));

  Future<List<PayrollPayment>> payroll({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query(
      'payroll_payments',
      where: start == null ? null : 'date >= ? AND date < ?',
      whereArgs: start == null
          ? null
          : [start.toIso8601String(), end!.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map(PayrollPayment.fromMap).toList();
  }

  Future<int> addAccount(BankAccount e) async =>
      (await database).insert('bank_accounts', e.toMap()..remove('id'));

  Future<List<BankAccount>> accounts() async =>
      (await (await database).query('bank_accounts', orderBy: 'name'))
          .map(BankAccount.fromMap)
          .toList();

  Future<int> addBankTransaction(BankTransaction e) async =>
      (await database).insert('bank_transactions', e.toMap()..remove('id'));

  Future<List<BankTransaction>> transactions({int? accountId}) async {
    final rows = await (await database).query(
      'bank_transactions',
      where: accountId == null ? null : 'account_id = ?',
      whereArgs: accountId == null ? null : [accountId],
      orderBy: 'date DESC',
    );
    return rows.map(BankTransaction.fromMap).toList();
  }

  Future<void> reconcile(BankTransaction tx,
      {required String ledgerType, required int ledgerId}) async {
    final db = await database;
    await db.transaction((txn) async {
      final changed = await txn.update(
        'bank_transactions',
        {'reconciled': 1},
        where: 'id = ? AND reconciled = 0',
        whereArgs: [tx.id],
      );
      if (changed != 1) {
        throw StateError('Bank transaction was already reconciled.');
      }
      await txn.insert('reconciliation_links', {
        'bank_transaction_id': tx.id,
        'ledger_type': ledgerType,
        'ledger_id': ledgerId,
        'matched_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<int> addStockCost(StockCost e) async =>
      (await database).insert('stock_costs', e.toMap()..remove('id'));

  Future<List<StockCost>> stockCosts() async =>
      (await (await database).query('stock_costs', orderBy: 'date DESC'))
          .map(StockCost.fromMap)
          .toList();

  Future<int> addIncome(IncomeEntry e) async =>
      (await database).insert('income_entries', e.toMap()..remove('id'));

  Future<List<IncomeEntry>> income({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query(
      'income_entries',
      where: start == null ? null : 'date >= ? AND date < ?',
      whereArgs: start == null
          ? null
          : [start.toIso8601String(), end!.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map(IncomeEntry.fromMap).toList();
  }
}
