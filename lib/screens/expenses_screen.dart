import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../widgets/finance_ui.dart';

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
  final search = TextEditingController();
  static const categories = [
    'Rent', 'Utilities', 'Transport', 'Supplies', 'Maintenance',
    'Salary-Monthly', 'Salary-Daily', 'Miscellaneous',
  ];

  @override
  void initState() { super.initState(); refresh(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> refresh() async {
    final values = await DatabaseService.instance.expenses();
    if (!mounted) return;
    setState(() { items = values; loading = false; });
  }

  Future<void> edit([ExpenseRecord? old]) async {
    final categoryController = TextEditingController(text: old?.category ?? 'Miscellaneous');
    final amountController = TextEditingController(text: old?.amount.toString() ?? '');
    final descriptionController = TextEditingController(text: old?.description ?? '');
    var date = old?.date ?? DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, update) => AlertDialog(
        title: Text(old == null ? 'Add expense' : 'Edit expense'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: categories.contains(categoryController.text) ? categoryController.text : 'Miscellaneous',
            items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => update(() => categoryController.text = value ?? 'Miscellaneous'),
          ),
          FinanceUi.amountField(amountController),
          TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(context: dialogContext, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) update(() => date = picked);
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(DateFormat('dd MMM yyyy').format(date)),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      )),
    );

    final amount = double.tryParse(amountController.text);
    if (ok == true && amount != null && amount > 0) {
      final record = ExpenseRecord(
        id: old?.id,
        date: date,
        category: categoryController.text,
        amount: amount,
        description: descriptionController.text.trim(),
      );
      if (old == null) {
        await DatabaseService.instance.addExpense(record);
      } else {
        await DatabaseService.instance.updateExpense(record);
      }
      await refresh();
    }
    categoryController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.where((entry) {
      final categoryMatches = category == 'All' || entry.category == category;
      final queryMatches = '${entry.category} ${entry.description} ${entry.amount}'
          .toLowerCase()
          .contains(query.toLowerCase());
      return categoryMatches && queryMatches;
    }).toList();
    final total = shown.fold<double>(0, (sum, entry) => sum + entry.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(
                    controller: search,
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search category or description'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: category,
                    items: ['All', ...categories].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: (value) => setState(() => category = value ?? 'All'),
                  ),
                  Card(child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: FinanceUi.row('Total shown (${shown.length})', total, bold: true),
                  )),
                ]),
              ),
              Expanded(
                child: shown.isEmpty
                    ? FinanceUi.empty('No expense records yet')
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, index) {
                          final entry = shown[index];
                          return ListTile(
                            title: Text(entry.description.isEmpty ? entry.category : entry.description),
                            subtitle: Text('${entry.category} • ${DateFormat('dd MMM yyyy').format(entry.date)}'),
                            trailing: Text(FinanceCalculator.money(entry.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () => edit(entry),
                            onLongPress: () async {
                              if (await FinanceUi.confirm(context, 'Delete this expense?')) {
                                await DatabaseService.instance.deleteExpense(entry.id!);
                                await refresh();
                              }
                            },
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
