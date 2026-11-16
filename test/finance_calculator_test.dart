import 'package:flutter_test/flutter_test.dart';
import 'package:billit_finance/models/finance_models.dart';
import 'package:billit_finance/services/finance_calculator.dart';

void main() {
  group('Finance records', () {
    test('expense record round trips through SQLite map representation', () {
      final original = ExpenseRecord(
        id: 7,
        date: DateTime(2026, 11, 16),
        category: 'Rent',
        amount: 12500,
        description: 'Shop rent',
      );
      final restored = ExpenseRecord.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.category, original.category);
      expect(restored.amount, original.amount);
      expect(restored.description, original.description);
    });

    test('employee record round trips through SQLite map representation', () {
      const original = EmployeeRecord(
        id: 3,
        name: 'Test Employee',
        type: 'monthly',
        wage: 18000,
      );
      final restored = EmployeeRecord.fromMap(original.toMap());
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.wage, original.wage);
    });

    test('currency formatter returns a non-empty value', () {
      expect(FinanceCalculator.money(1250), isNotEmpty);
    });
  });
}
