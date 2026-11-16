import 'package:flutter_test/flutter_test.dart';
import 'package:billit_finance/models/finance_models.dart';
import 'package:billit_finance/services/finance_calculator.dart';

void main() {
  group('FinanceCalculator', () {
    test('calculates net operating result', () {
      final summary = FinanceCalculator.summarize(
        income: [
          IncomeEntry(id: 1, date: DateTime(2026, 11, 1), source: 'Sales', amount: 10000),
        ],
        expenses: [
          ExpenseRecord(id: 1, date: DateTime(2026, 11, 2), category: 'Rent', amount: 1000, description: ''),
        ],
        payroll: [
          PayrollPayment(id: 1, employeeId: 1, date: DateTime(2026, 11, 3), period: '2026-11', amount: 2000, type: 'monthly'),
        ],
        stockCosts: [
          StockCost(id: 1, date: DateTime(2026, 11, 4), item: 'Item A', quantity: 5, unitCost: 100, kind: 'adjustment'),
        ],
      );
      expect(summary.income, 10000);
      expect(summary.expenses, 1000);
      expect(summary.payroll, 2000);
      expect(summary.cogs, 500);
      expect(summary.operatingResult, 6500);
    });

    test('purchase cost is not incorrectly counted as issued COGS', () {
      final summary = FinanceCalculator.summarize(
        income: const [],
        expenses: const [],
        payroll: const [],
        stockCosts: [
          StockCost(id: 1, date: DateTime(2026, 11, 4), item: 'Item A', quantity: 5, unitCost: 100, kind: 'purchase'),
        ],
      );
      expect(summary.cogs, 0);
    });
  });
}
