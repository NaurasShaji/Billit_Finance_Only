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
  const EmployeeRecord({required this.id, required this.name, required this.type, required this.wage, this.active = true, this.attendance = 0, this.salaryPaid = false});
  final int? id;
  final String name;
  final String type;
  final double wage;
  final bool active;
  final int attendance;
  final bool salaryPaid;
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'type': type, 'wage': wage, 'active': active ? 1 : 0, 'attendance': attendance, 'salary_paid': salaryPaid ? 1 : 0};
  factory EmployeeRecord.fromMap(Map<String, Object?> row) => EmployeeRecord(id: row['id'] as int, name: row['name'] as String, type: row['type'] as String, wage: (row['wage'] as num).toDouble(), active: (row['active'] as int) == 1, attendance: (row['attendance'] as int?) ?? 0, salaryPaid: ((row['salary_paid'] as int?) ?? 0) == 1);
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

class IncomeRecord {
  const IncomeRecord({this.id, required this.date, required this.amount, required this.description, this.costAmount = 0, this.source = 'manual', this.externalId});
  final int? id;
  final DateTime date;
  final double amount;
  final String description;
  final double costAmount;
  final String source;
  final String? externalId;
  Map<String, Object?> toMap() => {'id': id, 'date': date.toIso8601String(), 'amount': amount, 'description': description, 'cost_amount': costAmount, 'source': source, 'external_id': externalId};
  factory IncomeRecord.fromMap(Map<String, Object?> row) => IncomeRecord(id: row['id'] as int, date: DateTime.parse(row['date'] as String), amount: (row['amount'] as num).toDouble(), description: (row['description'] ?? '') as String, costAmount: (row['cost_amount'] as num?)?.toDouble() ?? 0, source: (row['source'] ?? 'manual') as String, externalId: row['external_id'] as String?);
}
class IncomePayment {
  const IncomePayment({this.id, required this.incomeId, required this.date, required this.method, required this.amount});
  final int? id;
  final int incomeId;
  final DateTime date;
  final String method;
  final double amount;
  Map<String, Object?> toMap() => {'id': id, 'income_id': incomeId, 'date': date.toIso8601String(), 'method': method, 'amount': amount};
  factory IncomePayment.fromMap(Map<String, Object?> row) => IncomePayment(id: row['id'] as int, incomeId: row['income_id'] as int, date: DateTime.parse(row['date'] as String), method: row['method'] as String, amount: (row['amount'] as num).toDouble());
}
class CreditParty {
  const CreditParty({this.id, required this.name, required this.type, this.phone = '', this.notes = ''});
  final int? id;
  final String name;
  final String type;
  final String phone;
  final String notes;
  Map<String, Object?> toMap() => {'id': id, 'name': name, 'type': type, 'phone': phone, 'notes': notes};
  factory CreditParty.fromMap(Map<String, Object?> row) => CreditParty(id: row['id'] as int, name: row['name'] as String, type: row['type'] as String, phone: (row['phone'] ?? '') as String, notes: (row['notes'] ?? '') as String);
}
class CreditTransaction {
  const CreditTransaction({this.id, required this.partyId, required this.date, required this.type, required this.amount, this.dueDate, this.note = '', this.incomeId});
  final int? id;
  final int partyId;
  final DateTime date;
  final String type;
  final double amount;
  final DateTime? dueDate;
  final String note;
  final int? incomeId;
  Map<String, Object?> toMap() => {'id': id, 'party_id': partyId, 'date': date.toIso8601String(), 'type': type, 'amount': amount, 'due_date': dueDate?.toIso8601String(), 'note': note, 'income_id': incomeId};
  factory CreditTransaction.fromMap(Map<String, Object?> row) => CreditTransaction(id: row['id'] as int, partyId: row['party_id'] as int, date: DateTime.parse(row['date'] as String), type: row['type'] as String, amount: (row['amount'] as num).toDouble(), dueDate: row['due_date'] == null ? null : DateTime.parse(row['due_date'] as String), note: (row['note'] ?? '') as String, incomeId: row['income_id'] as int?);
}
class CashSession {
  const CashSession({this.id, required this.date, required this.openingBalance, this.closingBalance, this.status = 'open'});
  final int? id;
  final DateTime date;
  final double openingBalance;
  final double? closingBalance;
  final String status;
  factory CashSession.fromMap(Map<String, Object?> row) => CashSession(id: row['id'] as int, date: DateTime.parse(row['date'] as String), openingBalance: (row['opening_balance'] as num).toDouble(), closingBalance: (row['closing_balance'] as num?)?.toDouble(), status: row['status'] as String);
}
class CashTransaction {
  const CashTransaction({this.id, required this.sessionId, required this.date, required this.direction, required this.method, required this.amount, this.category = '', this.note = ''});
  final int? id;
  final int sessionId;
  final DateTime date;
  final String direction;
  final String method;
  final double amount;
  final String category;
  final String note;
  Map<String, Object?> toMap() => {'id': id, 'session_id': sessionId, 'date': date.toIso8601String(), 'direction': direction, 'method': method, 'amount': amount, 'category': category, 'note': note};
  factory CashTransaction.fromMap(Map<String, Object?> row) => CashTransaction(id: row['id'] as int, sessionId: row['session_id'] as int, date: DateTime.parse(row['date'] as String), direction: row['direction'] as String, method: row['method'] as String, amount: (row['amount'] as num).toDouble(), category: (row['category'] ?? '') as String, note: (row['note'] ?? '') as String);
}
