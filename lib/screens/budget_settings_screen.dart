import 'package:flutter/material.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../widgets/ui_kit.dart';
import '../widgets/finance_ui.dart';

class BudgetSettingsPage extends StatefulWidget {
  const BudgetSettingsPage({super.key});
  @override
  State<BudgetSettingsPage> createState() => _BudgetSettingsPageState();
}

class _BudgetSettingsPageState extends State<BudgetSettingsPage> {
  final _total = TextEditingController();
  final _categoryAmount = TextEditingController();
  final _recurringAmount = TextEditingController();
  final _recurringNote = TextEditingController();
  String _category = 'Rent';
  String _recurringCategory = 'Rent';
  int _day = 1;
  bool _loading = true;
  List<CategoryBudget> _budgets = [];
  List<RecurringExpense> _recurring = [];
  late String _monthKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  @override
  void dispose() {
    _total.dispose();
    _categoryAmount.dispose();
    _recurringAmount.dispose();
    _recurringNote.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    final values = await Future.wait<Object?>([
      db.totalMonthlyBudget(_monthKey), db.categoryBudgets(_monthKey), db.recurringExpenses(),
    ]);
    if (!mounted) return;
    setState(() {
      _total.text = values[0]?.toString() ?? '';
      _budgets = values[1] as List<CategoryBudget>;
      _recurring = values[2] as List<RecurringExpense>;
      _loading = false;
    });
  }

  Future<void> _saveTotal() async {
    final value = double.tryParse(_total.text.trim());
    if (value == null || value <= 0) return;
    await DatabaseService.instance.saveMonthlyBudget(_monthKey, value);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monthly budget saved')));
  }

  Future<void> _saveCategory() async {
    final value = double.tryParse(_categoryAmount.text.trim());
    if (value == null || value <= 0) return;
    await DatabaseService.instance.saveCategoryBudget(CategoryBudget(monthKey: _monthKey, category: _category, limit: value));
    _categoryAmount.clear();
    await _load();
  }

  Future<void> _addRecurring() async {
    final value = double.tryParse(_recurringAmount.text.trim());
    if (value == null || value <= 0 || _recurringNote.text.trim().isEmpty) return;
    await DatabaseService.instance.saveRecurringExpense(RecurringExpense(
      category: _recurringCategory, amount: value, description: _recurringNote.text.trim(), dayOfMonth: _day,
    ));
    _recurringAmount.clear();
    _recurringNote.clear();
    await _load();
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 9),
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Budget & recurring bills')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ResponsiveBody(
      maxWidth: 760,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withValues(alpha: .78)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(children: [
            Icon(Icons.savings_outlined, color: Colors.white, size: 30),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Plan your shop spending', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              SizedBox(height: 4),
              Text('Set limits and keep recurring bills organised.', style: TextStyle(color: Colors.white70)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, Icons.account_balance_wallet_outlined, 'Monthly budget'),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(controller: _total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total monthly spending limit', prefixText: '₹ ')),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saveTotal, child: const Text('Save monthly budget')),
        ]))),
        const SizedBox(height: 16),
        _sectionTitle(context, Icons.donut_large_outlined, 'Category limits'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          DropdownButtonFormField<String>(value: _category, items: expenseCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _category = v ?? _category), decoration: const InputDecoration(labelText: 'Category')),
          TextField(controller: _categoryAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly category limit', prefixText: '₹ ')),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saveCategory, child: const Text('Save category limit')),
          if (_budgets.isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('No category limits yet. Add limits for rent, utilities or supplies.')),
          for (final b in _budgets) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.label_outline, color: Theme.of(context).colorScheme.primary)),
            title: Text(b.category, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(FinanceCalculator.money(b.limit), style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(tooltip: 'Remove category limit', icon: const Icon(Icons.delete_outline), onPressed: () async { await DatabaseService.instance.deleteCategoryBudget(_monthKey, b.category); await _load(); }),
            ]),
          ),
        ]))),
        const SizedBox(height: 16),
        _sectionTitle(context, Icons.event_repeat_outlined, 'Recurring bills'),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          DropdownButtonFormField<String>(value: _recurringCategory, items: expenseCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _recurringCategory = v ?? _recurringCategory), decoration: const InputDecoration(labelText: 'Category')),
          TextField(controller: _recurringNote, decoration: const InputDecoration(labelText: 'Bill name (e.g. Shop rent)')),
          TextField(controller: _recurringAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
          DropdownButtonFormField<int>(value: _day, items: List.generate(28, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('Every month on day $d'))).toList(), onChanged: (v) => setState(() => _day = v ?? 1)),
          const SizedBox(height: 10),
          FilledButton(onPressed: _addRecurring, child: const Text('Add recurring bill')),
          if (_recurring.isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('No recurring bills added yet.')),
          for (final item in _recurring) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.secondaryContainer, child: Icon(Icons.receipt_long_outlined, color: Theme.of(context).colorScheme.secondary)),
            title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text('${item.category} • Every month on day ${item.dayOfMonth}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(FinanceCalculator.money(item.amount)),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await DatabaseService.instance.deleteRecurringExpense(item.id!); await _load(); }),
            ]),
          ),
        ]))),
      ]),
    ),
  );
}
