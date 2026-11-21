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
import 'budget_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onNavigate, required this.onLogout});

  /// Switches the app shell to another tab.
  final ValueChanged<int> onNavigate;
  final VoidCallback onLogout;
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
  double collectedTotal = 0;
  double? monthlyLimit;
  List<CategoryBudget> categoryLimits = [];
  List<Map<String, Object?>> creditRows = [];

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
    await db.generateRecurringExpenses(DateTime.now());
    final monthKey = '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}';
    final values = await Future.wait<Object?>([
      db.expenses(start: start, end: end),
      db.payroll(start: start, end: end),
      db.income(start: start, end: end),
      db.expenses(start: prevStart, end: start),
      db.payroll(start: prevStart, end: start),
      db.income(start: prevStart, end: start),
      db.incomeCollected(start: start, end: end),
      db.totalMonthlyBudget(monthKey),
      db.categoryBudgets(monthKey),
      db.creditBalances(),
    ]);
    if (!mounted) return;
    final prevIncomeRows = values[5] as List<IncomeRecord>;
    final collected = values[6] as double;
    final budget = values[7] as double?;
    final limits = values[8] as List<CategoryBudget>;
    final credits = values[9] as List<Map<String, Object?>>;
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
      collectedTotal = collected;
      monthlyLimit = budget;
      categoryLimits = limits;
      creditRows = credits;
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
          AdminSettingsAction(onLogout: onLogout),
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
                          const SizedBox(height: 12),
                          _quickActions(),
                          const SizedBox(height: 12),
                          _stats(),
                          ExpansionTile(
                            title: const Text('More', style: TextStyle(fontWeight: FontWeight.w700)),
                            children: [
                              ListTile(leading: const Icon(Icons.groups_outlined), title: const Text('Payroll'), trailing: Text(FinanceCalculator.money(payrollTotal))),
                              for (final row in creditRows) ListTile(
                                leading: const Icon(Icons.account_balance_wallet_outlined),
                                title: Text((row['name'] ?? 'Credit party').toString()),
                                subtitle: Text((row['type'] ?? '').toString()),
                                trailing: Text(FinanceCalculator.money(((row['balance'] as num?)?.toDouble() ?? 0).abs())),
                              ),
                            ],
                          ),
                          const SectionHeader('Cash flow'),
                          _cashFlowCard(context),
                          if (expenseTotal > prevExpenses && prevExpenses > 0) ...[
                            const SectionHeader('Spending alert'),
                            Card(child: ListTile(
                              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                              title: const Text('Expenses are higher than last month'),
                              subtitle: Text('${FinanceCalculator.percentChange(expenseTotal, prevExpenses)!.toStringAsFixed(1)}% increase compared with the previous month'),
                            )),
                          ],
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
    final spent = expenseTotal;
    final remaining = monthlyLimit == null ? null : monthlyLimit! - spent;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: remaining != null && remaining < 0 ? [AppColors.negative, const Color(0xFF6E1F17)] : const [AppColors.brand, AppColors.brandDeep]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('MONTHLY BUDGET', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: .8))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)), child: Text(DateFormat('MMM yyyy').format(anchor), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        const Text('LEFT TO SPEND', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: .7)),
        const SizedBox(height: 8),
        FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(
          remaining == null ? 'Set a monthly budget' : remaining < 0 ? 'Over by ${FinanceCalculator.money(remaining.abs())}' : FinanceCalculator.money(remaining),
          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
        )),
        const SizedBox(height: 12),
        if (monthlyLimit != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(
            value: (spent / monthlyLimit!).clamp(0, 1), minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: .2),
            color: spent > monthlyLimit! ? Colors.white : Colors.white,
          )),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(child: Text('${FinanceCalculator.money(spent)} spent', style: const TextStyle(color: Colors.white70))),
          if (monthlyLimit != null) Text('of ${FinanceCalculator.money(monthlyLimit!)}', style: const TextStyle(color: Colors.white70)),
        ]),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
          onPressed: () => _open(const BudgetSettingsPage()),
          icon: const Icon(Icons.tune), label: const Text('Set budget'),
        )),
      ]),
    );
  }

  Widget _cashFlowCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        FinanceUiRow(label: 'Sales recorded', value: incomeTotal),
        FinanceUiRow(label: 'Collected from customers', value: collectedTotal),
        FinanceUiRow(label: 'Pending collection', value: (incomeTotal - collectedTotal).clamp(0, double.infinity).toDouble()),
        const Divider(),
        FinanceUiRow(label: 'Operating outflow', value: expenseTotal + payrollTotal, emphasize: true),
      ]),
    ),
  );

  Widget _quickActions() => Wrap(
    spacing: 10,
    runSpacing: 8,
    children: [
      FilledButton.icon(
        onPressed: () => _open(const IncomeEntryPage()),
        icon: const Icon(Icons.add_shopping_cart, size: 18),
        label: const Text('Add sale'),
      ),
      OutlinedButton.icon(
        onPressed: () => _open(const ExpenseEntryPage()),
        icon: const Icon(Icons.receipt_long, size: 18),
        label: const Text('Add expense'),
      ),
      OutlinedButton.icon(
        onPressed: () => widget.onNavigate(3),
        icon: const Icon(Icons.groups, size: 18),
        label: const Text('Pay staff'),
      ),
    ],
  );

  Widget _stats() {
    final margin = incomeTotal <= 0
        ? '–'
        : '${(netProfit / incomeTotal * 100).toStringAsFixed(1)}%';
    final items = <(String, String, Color)>[
      ('Sales', FinanceCalculator.money(incomeTotal), AppColors.positive),
      ('Cost of goods', FinanceCalculator.money(costOfGoodsSold), AppColors.brown),
      ('Gross profit', FinanceCalculator.money(grossProfit), grossProfit >= 0 ? AppColors.positive : AppColors.negative),
      ('Expenses', FinanceCalculator.money(expenseTotal), AppColors.warning),
      ('Margin', margin, AppColors.brand),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 5 : 2;
            final itemWidth = (constraints.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    width: itemWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].$1, style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: MaskedText(
                            items[i].$2,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: items[i].$3),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

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

