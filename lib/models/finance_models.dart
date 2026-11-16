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
