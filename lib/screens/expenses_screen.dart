import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../widgets/finance_ui.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'entry_form_screens.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}
class _ExpensesScreenState extends State<ExpensesScreen> {
  List<ExpenseRecord> items = [];
  bool loading = true;
  String query = '';
  String category = 'All';
  final List<String> customCategories = [];
  List<String> get allCategories => {...categories, ...customCategories, ...items.map((e) => e.category)}.toList()..sort();
  final search = TextEditingController();
  static const categories = ['Rent', 'Utilities', 'Transport', 'Supplies', 'Maintenance', 'Salary-Monthly', 'Salary-Daily', 'Miscellaneous'];
  @override
  void initState() { super.initState(); refresh(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  Future<void> refresh() async { final values = await DatabaseService.instance.expenses(); if (!mounted) return; setState(() { items = values; loading = false; }); }

  Future<void> edit([ExpenseRecord? old]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ExpenseEntryPage(existing: old),
    ));
    if (saved == true) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.where((entry) => (category == 'All' || entry.category == category) && ('${entry.category} ${entry.description} ${entry.amount}'.toLowerCase().contains(query.toLowerCase()))).toList();
    final total = shown.fold<double>(0, (sum, entry) => sum + entry.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses'), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Add expense')),
      body: loading ? const Center(child: CircularProgressIndicator()) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1040), child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(controller: search, onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search expenses')),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: DropdownButtonFormField<String>(value: category, items: ['All', ...allCategories].toSet().map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => category = value ?? 'All'), decoration: const InputDecoration(labelText: 'Filter category'))), const SizedBox(width: 12), Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total shown', style: TextStyle(color: AppColors.muted, fontSize: 12)), Text(FinanceCalculator.money(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))]))))]),
        ])),
        Expanded(child: shown.isEmpty ? const EmptyState(title: 'No expenses found', message: 'Add an expense or adjust your search and filters.', icon: Icons.receipt_long_outlined) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), itemCount: shown.length, separatorBuilder: (_, __) => const SizedBox(height: 4), itemBuilder: (context, index) {
          final entry = shown[index];
          return Card(child: ListTile(leading: CircleAvatar(backgroundColor: AppColors.brand.withValues(alpha: .10), child: const Icon(Icons.receipt_long, color: AppColors.brand)), title: Text(entry.description.isEmpty ? entry.category : entry.description, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${entry.category} • ${DateFormat('dd MMM yyyy').format(entry.date)}'), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(FinanceCalculator.money(entry.amount), style: const TextStyle(fontWeight: FontWeight.w800)), const Text('Expense', style: TextStyle(color: AppColors.muted, fontSize: 11))]), onTap: () => edit(entry), onLongPress: () async { if (await FinanceUi.confirm(context, 'Delete this expense?')) { await DatabaseService.instance.deleteExpense(entry.id!); await refresh(); } }));
        })),
      ]))),
    );
  }
}
