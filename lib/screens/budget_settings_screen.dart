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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Budget & recurring bills')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ResponsiveBody(
      maxWidth: 760,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Monthly budget', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(controller: _total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total monthly spending limit', prefixText: '₹ ')),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saveTotal, child: const Text('Save monthly budget')),
        ]))),
        const SizedBox(height: 16),
        const Text('Category limits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          DropdownButtonFormField<String>(value: _category, items: expenseCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _category = v ?? _category), decoration: const InputDecoration(labelText: 'Category')),
          TextField(controller: _categoryAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly category limit', prefixText: '₹ ')),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saveCategory, child: const Text('Save category limit')),
          for (final b in _budgets) ListTile(title: Text(b.category), trailing: Text(FinanceCalculator.money(b.limit))),
        ]))),
        const SizedBox(height: 16),
        const Text('Recurring bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          DropdownButtonFormField<String>(value: _recurringCategory, items: expenseCategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _recurringCategory = v ?? _recurringCategory), decoration: const InputDecoration(labelText: 'Category')),
          TextField(controller: _recurringNote, decoration: const InputDecoration(labelText: 'Bill name (e.g. Shop rent)')),
          TextField(controller: _recurringAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
          DropdownButtonFormField<int>(value: _day, items: List.generate(28, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('Every month on day $d'))).toList(), onChanged: (v) => setState(() => _day = v ?? 1)),
          const SizedBox(height: 10),
          FilledButton(onPressed: _addRecurring, child: const Text('Add recurring bill')),
          for (final item in _recurring) ListTile(
            title: Text(item.description), subtitle: Text('${item.category} • Day ${item.dayOfMonth}'),
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
