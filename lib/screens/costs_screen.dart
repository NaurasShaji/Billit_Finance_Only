import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';

class CostsScreen extends StatefulWidget {
  const CostsScreen({super.key});
  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends State<CostsScreen> {
  List<StockCost> costs = [];
  bool loading = true;
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final values = await DatabaseService.instance.stockCosts();
    if (!mounted) return;
    setState(() { costs = values; loading = false; });
  }

  Future<void> add() async {
    final item = TextEditingController();
    final quantity = TextEditingController();
    final unitCost = TextEditingController();
    final note = TextEditingController();
    var kind = 'adjustment';

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, update) => AlertDialog(
        title: const Text('Add stock-cost / COGS entry'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: item, decoration: const InputDecoration(labelText: 'Item / SKU')),
          TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity issued / adjusted')),
          TextField(controller: unitCost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit cost (₹)')),
          DropdownButtonFormField<String>(
            value: kind,
            items: const [
              DropdownMenuItem(value: 'purchase', child: Text('Purchase / restock')),
              DropdownMenuItem(value: 'opening', child: Text('Opening cost')),
              DropdownMenuItem(value: 'adjustment', child: Text('Issued / sold adjustment')),
            ],
            onChanged: (value) => update(() => kind = value ?? 'adjustment'),
          ),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      )),
    );

    final qty = double.tryParse(quantity.text);
    final cost = double.tryParse(unitCost.text);
    if (ok == true && item.text.trim().isNotEmpty && qty != null && qty > 0 && cost != null && cost >= 0) {
      await DatabaseService.instance.addStockCost(StockCost(
        id: null,
        date: DateTime.now(),
        item: item.text.trim(),
        quantity: qty,
        unitCost: cost,
        kind: kind,
        note: note.text.trim(),
      ));
      await load();
    }
    item.dispose(); quantity.dispose(); unitCost.dispose(); note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = costs
        .where((entry) => entry.kind == 'adjustment')
        .fold<double>(0, (sum, entry) => sum + entry.totalCost.abs());

    return Scaffold(
      appBar: AppBar(title: const Text('COGS & stock costs'), actions: [
        IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: const Text('Add cost entry'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Recorded COGS adjustments', style: TextStyle(color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  Text(FinanceCalculator.money(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('This total reflects entries marked issued / sold adjustment. Purchases and opening balances are retained separately. It is not a perpetual-inventory calculation.'),
                ]),
              )),
              Text('${costs.length} stock-cost entries', style: Theme.of(context).textTheme.titleMedium),
              ...costs.map((entry) => Card(child: ListTile(
                title: Text(entry.item),
                subtitle: Text('${entry.kind} • ${DateFormat('dd MMM yyyy').format(entry.date)} • Qty ${entry.quantity} × ${FinanceCalculator.money(entry.unitCost)}'),
                trailing: Text(FinanceCalculator.money(entry.totalCost), style: const TextStyle(fontWeight: FontWeight.w700)),
              ))),
            ]),
    );
  }
}
