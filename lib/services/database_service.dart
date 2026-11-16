import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/finance_models.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();
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
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
        await db.execute('CREATE INDEX idx_payroll_date ON payroll_payments(date)');
      },
    );
    return _db!;
  }

  Future<int> addExpense(ExpenseRecord e) async =>
      (await database).insert('expenses', e.toMap()..remove('id'));
  Future<int> updateExpense(ExpenseRecord e) async =>
      (await database).update('expenses', e.toMap()..remove('id'), where: 'id = ?', whereArgs: [e.id]);
  Future<int> deleteExpense(int id) async =>
      (await database).delete('expenses', where: 'id = ?', whereArgs: [id]);
  Future<List<ExpenseRecord>> expenses({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query(
      'expenses',
      where: start == null ? null : 'date >= ? AND date < ?',
      whereArgs: start == null ? null : [start.toIso8601String(), end!.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }
  Future<int> addEmployee(EmployeeRecord e) async =>
      (await database).insert('employees', e.toMap()..remove('id'));
  Future<List<EmployeeRecord>> employees() async =>
      (await (await database).query('employees', where: 'active = 1', orderBy: 'name'))
          .map(EmployeeRecord.fromMap).toList();
  Future<int> addPayroll(PayrollPayment e) async =>
      (await database).insert('payroll_payments', e.toMap()..remove('id'));
  Future<List<PayrollPayment>> payroll({DateTime? start, DateTime? end}) async {
    final rows = await (await database).query(
      'payroll_payments',
      where: start == null ? null : 'date >= ? AND date < ?',
      whereArgs: start == null ? null : [start.toIso8601String(), end!.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map(PayrollPayment.fromMap).toList();
  }
}
