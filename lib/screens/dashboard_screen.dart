import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_settings_action.dart';
import '../widgets/brand_header.dart';
import '../widgets/finance_ui.dart';
import '../widgets/ui_kit.dart';
import 'entry_form_screens.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Switches the app shell to another tab (0 overview … 5 backup).
  final ValueChanged<int> onNavigate;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _Activity {
  const _Activity({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.inflow,
    required this.icon,
  });
  final DateTime date;
  final String title;
  final String subtitle;
  final double amount;
  final bool inflow;
  final IconData icon;
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime anchor = DateTime.now();
  bool loaded = false;
  List<ExpenseRecord> expenses = [];
  List<PayrollPayment> payroll = [];
  List<IncomeRecord> income = [];
  double prevIncome = 0, prevCogs = 0, prevExpenses = 0, prevPayroll = 0;

  DateTime get start => DateTime(anchor.year, anchor.month, 1);
  DateTime get end => DateTime(anchor.year, anchor.month + 1, 1);
  DateTime get prevStart => DateTime(anchor.year, anchor.month - 1, 1);

  @override
  void initState() {
    super.initState();
    DatabaseService.revision.addListener(load);
    load();
  }

  @override
  void dispose() {
    DatabaseService.revision.removeListener(load);
    super.dispose();
  }

  Future<void> load() async {
    final db = DatabaseService.instance;
    final values = await Future.wait<Object>([
      db.expenses(start: start, end: end),
      db.payroll(start: start, end: end),
      db.income(start: start, end: end),
      db.expenses(start: prevStart, end: start),
      db.payroll(start: prevStart, end: start),
      db.income(start: prevStart, end: start),
    ]);
    if (!mounted) return;
    final prevIncomeRows = values[5] as List<IncomeRecord>;
    setState(() {
      expenses = values[0] as List<ExpenseRecord>;
      payroll = values[1] as List<PayrollPayment>;
      income = values[2] as List<IncomeRecord>;
      prevExpenses = (values[3] as List<ExpenseRecord>).fold<double>(
        0,
        (s, e) => s + e.amount,
      );
      prevPayroll = (values[4] as List<PayrollPayment>).fold<double>(
        0,
        (s, e) => s + e.amount,
      );
      prevIncome = prevIncomeRows.fold<double>(0, (s, e) => s + e.amount);
      prevCogs = prevIncomeRows.fold<double>(0, (s, e) => s + e.costAmount);
      loaded = true;
    });
  }

  double get expenseTotal => expenses.fold<double>(0, (s, e) => s + e.amount);
  double get payrollTotal => payroll.fold<double>(0, (s, e) => s + e.amount);
  double get incomeTotal => income.fold<double>(0, (s, e) => s + e.amount);
  double get costOfGoodsSold =>
      income.fold<double>(0, (s, e) => s + e.costAmount);
  double get grossProfit => incomeTotal - costOfGoodsSold;
  double get netProfit => grossProfit - expenseTotal - payrollTotal;
  double get prevNet => prevIncome - prevCogs - prevExpenses - prevPayroll;
  double get outflow => costOfGoodsSold + expenseTotal + payrollTotal;

  void _shift(int months) {
    setState(() => anchor = DateTime(anchor.year, anchor.month + months, 1));
    load();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => page));
    await load();
  }

  List<_Activity> get activity {
    final rows = <_Activity>[
      for (final e in income)
        _Activity(
          date: e.date,
          title: e.description.isEmpty ? 'Sale' : e.description,
          subtitle: 'Sale',
          amount: e.amount,
          inflow: true,
          icon: Icons.south_west,
        ),
      for (final e in expenses)
        _Activity(
          date: e.date,
          title: e.description.isEmpty ? e.category : e.description,
          subtitle: e.category,
          amount: e.amount,
          inflow: false,
          icon: categoryIcon(e.category),
        ),
      for (final e in payroll)
        _Activity(
          date: e.date,
          title: e.type == 'daily' ? 'Daily wage' : 'Monthly salary',
          subtitle: 'Payroll',
          amount: e.amount,
          inflow: false,
          icon: Icons.groups_outlined,
        ),
    ];
    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandHeader(),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: hideAmounts,
            builder: (context, hidden, _) => IconButton(
              tooltip: hidden ? 'Show amounts' : 'Hide amounts',
              onPressed: () => hideAmounts.value = !hidden,
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          const AdminSettingsAction(),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PeriodSwitcher(
                            label: DateFormat('MMMM yyyy').format(anchor),
                            onPrevious: () => _shift(-1),
                            onNext: () => _shift(1),
                          ),
                          const SizedBox(height: 8),
                          _hero(context),
                          const SizedBox(height: 12),
                          _quickActions(),
                          const SizedBox(height: 12),
                          _stats(),
                          const SectionHeader('Spending breakdown'),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: BreakdownBar(
                                segments: [
                                  BarSegment(
                                    'Cost of goods',
                                    costOfGoodsSold,
                                    AppColors.brown,
                                  ),
                                  BarSegment(
                                    'Expenses',
                                    expenseTotal,
                                    AppColors.warning,
                                  ),
                                  BarSegment(
                                    'Payroll',
                                    payrollTotal,
                                    AppColors.indigo,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SectionHeader('Recent activity'),
                          _activityCard(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _hero(BuildContext context) {
    final positive = netProfit >= 0;
    final delta = FinanceCalculator.percentChange(netProfit, prevNet);
    final colors = positive
        ? const [AppColors.brand, AppColors.brandDeep]
        : const [Color(0xFFA33327), Color(0xFF6E1F17)];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Net result',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Tooltip(
                message: 'Sales less cost of goods, expenses and payroll. Not a tax or statutory profit.',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: Duration(seconds: 4),
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${delta >= 0 ? '▲' : '▼'} ${delta.abs().toStringAsFixed(0)}% vs last month',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: netProfit),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MaskedText(
                FinanceCalculator.money(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroFigure('Sales', incomeTotal, Icons.south_west),
              ),
              Expanded(child: _heroFigure('Spent', outflow, Icons.north_east)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroFigure(String label, double value, IconData icon) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MaskedText(
                FinanceCalculator.money(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _quickActions() => Row(
    children: [
      Expanded(
        child: _QuickAction(
          icon: Icons.add_shopping_cart,
          label: 'Add sale',
          onTap: () => _open(const IncomeEntryPage()),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickAction(
          icon: Icons.receipt_long,
          label: 'Add expense',
          onTap: () => _open(const ExpenseEntryPage()),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickAction(
          icon: Icons.groups,
          label: 'Pay staff',
          onTap: () => widget.onNavigate(3),
        ),
      ),
    ],
  );

  Widget _stats() => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 900 ? 3 : 2;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      final margin = incomeTotal <= 0
          ? '–'
          : '${(netProfit / incomeTotal * 100).toStringAsFixed(1)}%';
      final tiles = <Widget>[
        StatCard(
          title: 'Sales',
          value: FinanceCalculator.money(incomeTotal),
          icon: Icons.trending_up,
          color: AppColors.positive,
          delta: FinanceCalculator.percentChange(incomeTotal, prevIncome),
        ),
        StatCard(
          title: 'Cost of goods',
          value: FinanceCalculator.money(costOfGoodsSold),
          icon: Icons.inventory_2_outlined,
          color: AppColors.brown,
          delta: FinanceCalculator.percentChange(costOfGoodsSold, prevCogs),
          lowerIsBetter: true,
        ),
        StatCard(
          title: 'Gross profit',
          value: FinanceCalculator.money(grossProfit),
          icon: Icons.show_chart,
          color: grossProfit >= 0 ? AppColors.positive : AppColors.negative,
        ),
        StatCard(
          title: 'Expenses',
          value: FinanceCalculator.money(expenseTotal),
          icon: Icons.receipt_long,
          color: AppColors.warning,
          delta: FinanceCalculator.percentChange(expenseTotal, prevExpenses),
          lowerIsBetter: true,
        ),
        StatCard(
          title: 'Payroll',
          value: FinanceCalculator.money(payrollTotal),
          icon: Icons.groups,
          color: AppColors.indigo,
          delta: FinanceCalculator.percentChange(payrollTotal, prevPayroll),
          lowerIsBetter: true,
        ),
        StatCard(
          title: 'Margin',
          value: margin,
          icon: Icons.percent,
          color: AppColors.brand,
          mask: false,
        ),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final tile in tiles) SizedBox(width: width, child: tile),
        ],
      );
    },
  );

  Widget _activityCard(BuildContext context) {
    final rows = activity;
    if (rows.isEmpty) {
      return const Card(
        child: EmptyState(title: 'No activity this month', icon: Icons.history),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: CircleAvatar(
                radius: 19,
                backgroundColor: (rows[i].inflow ? context.good : context.muted)
                    .withValues(alpha: .14),
                child: Icon(
                  rows[i].icon,
                  size: 18,
                  color: rows[i].inflow ? context.good : context.muted,
                ),
              ),
              title: Text(
                rows[i].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${rows[i].subtitle} • ${dayLabel(rows[i].date)}'),
              trailing: MaskedText(
                '${rows[i].inflow ? '+' : '−'}${FinanceCalculator.money(rows[i].amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: rows[i].inflow ? context.good : context.ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.accent.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: context.accent),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
