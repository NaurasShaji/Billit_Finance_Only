import 'package:flutter/material.dart';
import '../widgets/admin_settings_action.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../widgets/brand_header.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

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
    setState(() { expenses = values[0] as List<ExpenseRecord>; payroll = values[1] as List<PayrollPayment>; employees = values[2] as List<EmployeeRecord>; income = values[3] as List<IncomeRecord>; loading = false; });
  }
  double get expenseTotal => expenses.fold(0, (s,e) => s + e.amount);
  double get payrollTotal => payroll.fold(0, (s,e) => s + e.amount);
  double get incomeTotal => income.fold(0, (s,e) => s + e.amount);
  double get costOfGoodsSold => income.fold(0, (s,e) => s + e.costAmount);
  double get grossProfit => incomeTotal - costOfGoodsSold;
  double get netProfit => grossProfit - expenseTotal - payrollTotal;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandHeader(), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh)), const AdminSettingsAction()]),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1120), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Finance overview', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink)),
        const Text('Income, expenses and payroll monitoring', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        PeriodSwitcher(label: DateFormat('MMMM yyyy').format(anchor), onPrevious: () { setState(() => anchor = DateTime(anchor.year, anchor.month - 1, 1)); load(); }, onNext: () { setState(() => anchor = DateTime(anchor.year, anchor.month + 1, 1)); load(); }),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth >= 900 ? 3 : box.maxWidth >= 560 ? 2 : 1;
          final width = (box.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: width, child: StatCard(title: 'Sales / income', value: FinanceCalculator.money(incomeTotal), icon: Icons.trending_up, color: AppColors.positive)),
            SizedBox(width: width, child: StatCard(title: 'Cost of goods sold', value: FinanceCalculator.money(costOfGoodsSold), icon: Icons.inventory_2_outlined, color: Colors.brown)),
            SizedBox(width: width, child: StatCard(title: 'Gross profit', value: FinanceCalculator.money(grossProfit), icon: Icons.show_chart, color: grossProfit >= 0 ? AppColors.positive : AppColors.negative)),
            SizedBox(width: width, child: StatCard(title: 'Total expenses', value: FinanceCalculator.money(expenseTotal), icon: Icons.receipt_long, color: AppColors.warning)),
            SizedBox(width: width, child: StatCard(title: 'Payroll paid', value: FinanceCalculator.money(payrollTotal), icon: Icons.groups, color: Colors.indigo)),
            SizedBox(width: width, child: StatCard(title: 'Net operating result', value: FinanceCalculator.money(netProfit), icon: Icons.account_balance, color: netProfit >= 0 ? AppColors.positive : AppColors.negative)),
          ]);
        }),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('Monthly summary'),
          _line('Income entries', '${income.length}'), _line('Expense entries', '${expenses.length}'), _line('Payroll payments', '${payroll.length}'), _line('Active employees', '${employees.length}'),
          const Divider(height: 22), _line('Total income', FinanceCalculator.money(incomeTotal)), _line('Cost of goods sold', FinanceCalculator.money(costOfGoodsSold)), _line('Gross profit', FinanceCalculator.money(grossProfit)), _line('Total expenses', FinanceCalculator.money(expenseTotal)), _line('Total payroll', FinanceCalculator.money(payrollTotal)), _line('Net operating result', FinanceCalculator.money(netProfit), bold: true),
        ]))),
      ]))),
    ])),
  );
  Widget _line(String label, String value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600))]));
}
