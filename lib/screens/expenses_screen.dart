import 'package:flutter/material.dart';

import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_settings_action.dart';
import '../widgets/finance_ui.dart';
import '../widgets/ui_kit.dart';
import 'entry_form_screens.dart';
import 'budget_settings_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _Row {
  const _Row.header(this.label, this.total) : entry = null;
  const _Row.item(this.entry) : label = null, total = 0;
  final String? label;
  final double total;
  final ExpenseRecord? entry;
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<ExpenseRecord> items = [];
  bool loading = true;
  String query = '';
  String category = 'All';
  final search = TextEditingController();

  List<String> get allCategories =>
      {...expenseCategories, ...items.map((e) => e.category)}.toList()..sort();

  @override
  void initState() {
    super.initState();
    DatabaseService.revision.addListener(refresh);
    refresh();
  }

  @override
  void dispose() {
    DatabaseService.revision.removeListener(refresh);
    search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    await DatabaseService.instance.generateRecurringExpenses(DateTime.now());
    final values = await DatabaseService.instance.expenses();
    if (!mounted) return;
    setState(() {
      items = values;
      loading = false;
    });
  }

  Future<void> edit([ExpenseRecord? old]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExpenseEntryPage(existing: old)),
    );
    await refresh();
  }

  Future<void> _delete(ExpenseRecord entry) async {
    setState(() => items.removeWhere((e) => e.id == entry.id));
    await DatabaseService.instance.deleteExpense(entry.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Expense deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await DatabaseService.instance.addExpense(
                ExpenseRecord(
                  id: null,
                  date: entry.date,
                  category: entry.category,
                  amount: entry.amount,
                  description: entry.description,
                  receiptPath: entry.receiptPath,
                ),
              );
              await refresh();
            },
          ),
        ),
      );
  }

  List<ExpenseRecord> get shown {
    final q = query.trim().toLowerCase();
    return items
        .where(
          (e) =>
              (category == 'All' || e.category == category) &&
              (q.isEmpty ||
                  '${e.category} ${e.description} ${e.amount}'
                      .toLowerCase()
                      .contains(q)),
        )
        .toList();
  }

  List<_Row> _rows(List<ExpenseRecord> entries) {
    final groups = <String, List<ExpenseRecord>>{};
    for (final e in entries) {
      groups.putIfAbsent(dayLabel(e.date), () => []).add(e);
    }
    return [
      for (final g in groups.entries) ...[
        _Row.header(g.key, g.value.fold<double>(0, (s, e) => s + e.amount)),
        for (final e in g.value) _Row.item(e),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = shown;
    final total = entries.fold<double>(0, (sum, e) => sum + e.amount);
    final rows = _rows(entries);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final previousStart = DateTime(now.year, now.month - 1, 1);
    final monthExpenses = items.where((e) => !e.date.isBefore(monthStart) && e.date.isBefore(DateTime(now.year, now.month + 1, 1))).toList();
    final previousExpenses = items.where((e) => !e.date.isBefore(previousStart) && e.date.isBefore(monthStart)).fold<double>(0, (s, e) => s + e.amount);
    final monthTotal = monthExpenses.fold<double>(0, (s, e) => s + e.amount);
    final categoryTotals = <String, double>{};
    for (final item in monthExpenses) { categoryTotals[item.category] = (categoryTotals[item.category] ?? 0) + item.amount; }
    final largestCategory = categoryTotals.entries.isEmpty ? null : (categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(tooltip: 'Budget and recurring bills', icon: const Icon(Icons.tune), onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetSettingsPage()));
            await refresh();
          }),
          const AdminSettingsAction(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: TextField(
                        controller: search,
                        onChanged: (value) => setState(() => query = value),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search expenses by name, category or amount',
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    search.clear();
                                    setState(() => query = '');
                                  },
                                ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [context.accent.withValues(alpha: .10), context.softFill],
                            ),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 38, height: 38, decoration: BoxDecoration(color: context.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.payments_outlined, color: context.accent)),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('TOTAL SPENT THIS MONTH', style: TextStyle(color: context.muted, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: .5)),
                                const SizedBox(height: 4),
                                MaskedText(FinanceCalculator.money(monthTotal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              ])),
                              if (previousExpenses > 0) StatusPill(
                                '${FinanceCalculator.percentChange(monthTotal, previousExpenses)!.abs().toStringAsFixed(0)}% ${monthTotal >= previousExpenses ? 'up' : 'down'}',
                                monthTotal > previousExpenses ? AppColors.warning : context.good,
                              ),
                            ]),
                            const SizedBox(height: 12),
                            if (largestCategory != null) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Icon(categoryIcon(largestCategory.key), size: 17, color: context.muted),
                                const SizedBox(width: 7),
                                Expanded(child: Text('Highest: ${largestCategory.key}', style: TextStyle(color: context.muted, fontWeight: FontWeight.w600))),
                                MaskedText(FinanceCalculator.money(largestCategory.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ]),
                            ],
                          ]),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final c in ['All', ...allCategories])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: category == c,
                                onSelected: (_) => setState(() => category = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Row(
                        children: [
                          Text(
                            '${entries.length} ${entries.length == 1 ? 'expense' : 'expenses'}',
                            style: TextStyle(
                              color: context.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          MaskedText(
                            FinanceCalculator.money(total),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? EmptyState(
                              title: items.isEmpty
                                  ? 'No expenses yet'
                                  : 'No matches',
                              icon: Icons.receipt_long_outlined,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                              itemCount: rows.length,
                              itemBuilder: (context, i) {
                                final row = rows[i];
                                if (row.entry == null) {
                                  return DayHeader(
                                    label: row.label!,
                                    total: row.total,
                                  );
                                }
                                return _tile(context, row.entry!);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, ExpenseRecord entry) {
    final hasNote = entry.description.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Dismissible(
        key: ValueKey('expense-${entry.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(entry),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: AppColors.negative,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => edit(entry),
            leading: CircleAvatar(
              backgroundColor: context.accent.withValues(alpha: .12),
              child: Icon(categoryIcon(entry.category), color: context.accent),
            ),
            title: Text(
              hasNote ? entry.description : entry.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: hasNote ? Text(entry.category) : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (entry.receiptPath != null) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.attachment_outlined, size: 17, color: context.accent)),
              IconButton(
                tooltip: 'Repeat this expense',
                icon: const Icon(Icons.replay_outlined, size: 20),
                onPressed: () async {
                  await DatabaseService.instance.addExpense(ExpenseRecord(
                    id: null,
                    date: DateTime.now(), category: entry.category, amount: entry.amount,
                    description: entry.description,
                  ));
                  await refresh();
                },
              ),
              MaskedText(FinanceCalculator.money(entry.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}
