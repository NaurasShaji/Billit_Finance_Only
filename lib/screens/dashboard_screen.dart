import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../widgets/brand_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  DateTime anchor = DateTime.now();
  bool loading = true;
  List<ExpenseRecord> expenses = [];
  List<PayrollPayment> payroll = [];
  List<IncomeRecord> income = [];
  List<EmployeeRecord> employees = [];
  DateTime get start => DateTime(anchor.year, anchor.month, 1);
  DateTime get end => DateTime(anchor.year, anchor.month + 1, 1);

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() => loading = true);
    final values = await Future.wait([
      DatabaseService.instance.expenses(start: start, end: end),
      DatabaseService.instance.payroll(start: start, end: end),
      DatabaseService.instance.employees(),
      DatabaseService.instance.income(start: start, end: end),
    ]);
    if (!mounted) return;
    setState(() {
      expenses = values[0] as List<ExpenseRecord>;
      payroll = values[1] as List<PayrollPayment>;
      employees = values[2] as List<EmployeeRecord>;
      income = values[3] as List<IncomeRecord>;
      loading = false;
    });
  }
  double get expenseTotal => expenses.fold(0, (sum, e) => sum + e.amount);
  double get payrollTotal => payroll.fold(0, (sum, e) => sum + e.amount);
  double get incomeTotal => income.fold(0, (sum, e) => sum + e.amount);
  double get costOfGoodsSold => income.fold(0, (sum, e) => sum + e.costAmount);
  double get grossProfit => incomeTotal - costOfGoodsSold;
  double get netProfit => grossProfit - expenseTotal - payrollTotal;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandHeader(), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Finance overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const Text('Income, expenses and payroll monitoring'),
        Card(child: Row(children: [
          IconButton(onPressed: () { setState(() => anchor = DateTime(anchor.year, anchor.month - 1, 1)); load(); }, icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(DateFormat('MMMM yyyy').format(anchor), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          IconButton(onPressed: () { setState(() => anchor = DateTime(anchor.year, anchor.month + 1, 1)); load(); }, icon: const Icon(Icons.chevron_right)),
        ])),
        const SizedBox(height: 12),
        _metric('Sales / income', incomeTotal, Icons.trending_up, Colors.green),
        _metric('Cost of goods sold', costOfGoodsSold, Icons.inventory_2_outlined, Colors.brown),
        _metric('Gross profit', grossProfit, Icons.show_chart, grossProfit >= 0 ? Colors.green : Colors.red),
        _metric('Total expenses', expenseTotal, Icons.receipt_long, Colors.deepOrange),
        _metric('Payroll paid', payrollTotal, Icons.groups, Colors.indigo),
        _metric('Total outflow', expenseTotal + payrollTotal, Icons.account_balance_wallet, const Color(0xFF087E70)),
        _metric('Net operating result', netProfit, Icons.account_balance, netProfit >= 0 ? Colors.green : Colors.red),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Monthly summary', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _line('Income entries', '${income.length}'),
          _line('Expense entries', '${expenses.length}'),
          _line('Payroll payments', '${payroll.length}'),
          _line('Active employees', '${employees.length}'),
          const Divider(),
          _line('Total income', FinanceCalculator.money(incomeTotal)),
          _line('Cost of goods sold', FinanceCalculator.money(costOfGoodsSold)),
          _line('Gross profit', FinanceCalculator.money(grossProfit)),
          _line('Total expenses', FinanceCalculator.money(expenseTotal)),
          _line('Net operating result', FinanceCalculator.money(netProfit)),
          _line('Total payroll', FinanceCalculator.money(payrollTotal)),
        ]))),
      ]),
    ),
  );
  Widget _metric(String label, double value, IconData icon, Color color) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
      const SizedBox(width: 14),
      Expanded(child: Text(label)),
      Text(FinanceCalculator.money(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
    ])),
  );
  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
  );
}
