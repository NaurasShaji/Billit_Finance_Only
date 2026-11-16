import 'package:intl/intl.dart';
import '../models/finance_models.dart';

class FinanceSummary {
  const FinanceSummary({
    required this.income,
    required this.expenses,
    required this.payroll,
    required this.cogs,
  });

  final double income;
  final double expenses;
  final double payroll;
  final double cogs;

  // Separate payroll from ordinary expense totals to avoid duplicate counting.
  double get totalOutflow => expenses + payroll + cogs;
  double get operatingResult => income - totalOutflow;
}

class FinanceCalculator {
  static FinanceSummary summarize({
    required List<IncomeEntry> income,
    required List<ExpenseRecord> expenses,
    required List<PayrollPayment> payroll,
    required List<StockCost> stockCosts,
  }) {
    final incomeTotal = income.fold<double>(0, (sum, item) => sum + item.amount);
    final expenseTotal = expenses.fold<double>(0, (sum, item) => sum + item.amount);
    final payrollTotal = payroll.fold<double>(0, (sum, item) => sum + item.amount);
    final cogsTotal = stockCosts
        .where((item) => item.kind == 'adjustment')
        .fold<double>(0, (sum, item) => sum + item.totalCost.abs());

    return FinanceSummary(
      income: incomeTotal,
      expenses: expenseTotal,
      payroll: payrollTotal,
      cogs: cogsTotal,
    );
  }

  static String money(num value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
}
