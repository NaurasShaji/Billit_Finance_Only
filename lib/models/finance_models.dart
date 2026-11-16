class ExpenseRecord {
  const ExpenseRecord({required this.id, required this.date, required this.category, required this.amount, required this.description});
  final int? id;
  final DateTime date;
  final String category;
  final double amount;
  final String description;
  Map<String, Object?> toMap() => {'id': id, 'date': date.toIso8601String(), 'category': category, 'amount': amount, 'description': description};
  factory ExpenseRecord.fromMap(Map<String, Object?> row) => ExpenseRecord(id: row['id'] as int, date: DateTime.parse(row['date'] as String), category: row['category'] as String, amount: (row['amount'] as num).toDouble(), description: (row['description'] ?? '') as String);
}

class EmployeeRecord {
  const EmployeeRecord({required this.id, required this.name, required this.type, required this.wage, this.active = true});
  final int? id;
  final String name;
  final String type;
  final double wage;
  final bool active;
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'type': type, 'wage': wage, 'active': active ? 1 : 0};
  factory EmployeeRecord.fromMap(Map<String, Object?> row) => EmployeeRecord(id: row['id'] as int, name: row['name'] as String, type: row['type'] as String, wage: (row['wage'] as num).toDouble(), active: (row['active'] as int) == 1);
}

class PayrollPayment {
  const PayrollPayment({required this.id, required this.employeeId, required this.date, required this.period, required this.amount, required this.type, this.note = ''});
  final int? id;
  final int employeeId;
  final DateTime date;
  final String period;
  final double amount;
  final String type;
  final String note;
  Map<String, Object?> toMap() => {'id': id, 'employee_id': employeeId, 'date': date.toIso8601String(), 'period': period, 'amount': amount, 'type': type, 'note': note};
  factory PayrollPayment.fromMap(Map<String, Object?> row) => PayrollPayment(id: row['id'] as int, employeeId: row['employee_id'] as int, date: DateTime.parse(row['date'] as String), period: row['period'] as String, amount: (row['amount'] as num).toDouble(), type: row['type'] as String, note: (row['note'] ?? '') as String);
}

class BankAccount {
  const BankAccount({required this.id, required this.name, required this.bankName, required this.openingBalance});
  final int? id;
  final String name;
  final String bankName;
  final double openingBalance;
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'bank_name': bankName, 'opening_balance': openingBalance};
  factory BankAccount.fromMap(Map<String, Object?> row) => BankAccount(id: row['id'] as int, name: row['name'] as String, bankName: row['bank_name'] as String, openingBalance: (row['opening_balance'] as num).toDouble());
}

class BankTransaction {
  const BankTransaction({required this.id, required this.accountId, required this.date, required this.description, required this.amount, required this.direction, required this.reference, this.reconciled = false});
  final int? id;
  final int accountId;
  final DateTime date;
  final String description;
  final double amount;
  final String direction;
  final String reference;
  final bool reconciled;
  Map<String, Object?> toMap() => {'id': id, 'account_id': accountId, 'date': date.toIso8601String(), 'description': description, 'amount': amount, 'direction': direction, 'reference': reference, 'reconciled': reconciled ? 1 : 0};
  factory BankTransaction.fromMap(Map<String, Object?> row) => BankTransaction(id: row['id'] as int, accountId: row['account_id'] as int, date: DateTime.parse(row['date'] as String), description: row['description'] as String, amount: (row['amount'] as num).toDouble(), direction: row['direction'] as String, reference: (row['reference'] ?? '') as String, reconciled: (row['reconciled'] as int) == 1);
}

class StockCost {
  const StockCost({required this.id, required this.date, required this.item, required this.quantity, required this.unitCost, required this.kind, this.note = ''});
  final int? id;
  final DateTime date;
  final String item;
  final double quantity;
  final double unitCost;
  final String kind;
  final String note;
  double get totalCost => quantity * unitCost;
  Map<String, Object?> toMap() => {'id': id, 'date': date.toIso8601String(), 'item': item, 'quantity': quantity, 'unit_cost': unitCost, 'kind': kind, 'note': note};
  factory StockCost.fromMap(Map<String, Object?> row) => StockCost(id: row['id'] as int, date: DateTime.parse(row['date'] as String), item: row['item'] as String, quantity: (row['quantity'] as num).toDouble(), unitCost: (row['unit_cost'] as num).toDouble(), kind: row['kind'] as String, note: (row['note'] ?? '') as String);
}

class IncomeEntry {
  const IncomeEntry({required this.id, required this.date, required this.source, required this.amount, this.note = ''});
  final int? id;
  final DateTime date;
  final String source;
  final double amount;
  final String note;
  Map<String, Object?> toMap() => {'id': id, 'date': date.toIso8601String(), 'source': source, 'amount': amount, 'note': note};
  factory IncomeEntry.fromMap(Map<String, Object?> row) => IncomeEntry(id: row['id'] as int, date: DateTime.parse(row['date'] as String), source: row['source'] as String, amount: (row['amount'] as num).toDouble(), note: (row['note'] ?? '') as String);
}
