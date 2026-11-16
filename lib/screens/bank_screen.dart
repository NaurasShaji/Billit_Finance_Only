import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';

class BankScreen extends StatefulWidget {
  const BankScreen({super.key});
  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  List<BankAccount> accounts = [];
  List<BankTransaction> transactions = [];
  bool loading = true;
  int? selected;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final accountRows = await DatabaseService.instance.accounts();
    final transactionRows = await DatabaseService.instance.transactions(accountId: selected);
    if (!mounted) return;
    setState(() {
      accounts = accountRows;
      transactions = transactionRows;
      loading = false;
      if (selected == null && accounts.isNotEmpty) selected = accounts.first.id;
    });
  }

  Future<void> addAccount() async {
    final name = TextEditingController();
    final bank = TextEditingController();
    final balance = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add bank account'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Account label')),
          TextField(controller: bank, decoration: const InputDecoration(labelText: 'Bank name')),
          TextField(controller: balance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening balance')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    final amount = double.tryParse(balance.text);
    if (ok == true && name.text.trim().isNotEmpty && bank.text.trim().isNotEmpty && amount != null) {
      await DatabaseService.instance.addAccount(BankAccount(
        id: null, name: name.text.trim(), bankName: bank.text.trim(), openingBalance: amount,
      ));
      await load();
    }
    name.dispose(); bank.dispose(); balance.dispose();
  }

  Future<void> addTransaction() async {
    if (accounts.isEmpty) { await addAccount(); if (accounts.isEmpty) return; }
    final description = TextEditingController();
    final amountController = TextEditingController();
    final reference = TextEditingController();
    var account = selected ?? accounts.first.id!;
    var direction = 'debit';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, update) => AlertDialog(
        title: const Text('Statement transaction'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            value: account,
            items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
            onChanged: (value) => update(() => account = value ?? account),
          ),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
          TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
          TextField(controller: reference, decoration: const InputDecoration(labelText: 'Reference')),
          DropdownButtonFormField<String>(
            value: direction,
            items: const [DropdownMenuItem(value: 'debit', child: Text('Debit')), DropdownMenuItem(value: 'credit', child: Text('Credit'))],
            onChanged: (value) => update(() => direction = value ?? 'debit'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
        ],
      )),
    );
    final amount = double.tryParse(amountController.text);
    if (ok == true && amount != null && amount > 0) {
      await DatabaseService.instance.addBankTransaction(BankTransaction(
        id: null, accountId: account, date: DateTime.now(), description: description.text.trim(),
        amount: amount, direction: direction, reference: reference.text.trim(),
      ));
      await load();
    }
    description.dispose(); amountController.dispose(); reference.dispose();
  }

  Future<void> match(BankTransaction transaction) async {
    final db = await DatabaseService.instance.database;
    final table = transaction.direction == 'debit' ? 'expenses' : 'income_entries';
    final rows = await db.query(table, where: 'ABS(amount - ?) < 0.01', whereArgs: [transaction.amount], orderBy: 'date DESC');
    if (rows.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No same-amount ledger entry found.')),
      );
      return;
    }
    final choice = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose matching entry'),
        children: rows.map((row) {
          final id = row['id'] as int;
          final date = DateTime.parse(row['date'] as String);
          final label = (row['description'] ?? row['source'] ?? row['category'] ?? 'Ledger entry').toString();
          final value = (row['amount'] as num).toDouble();
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, id),
            child: Text('$label • ${DateFormat('dd MMM yyyy').format(date)} • ${FinanceCalculator.money(value)}'),
          );
        }).toList(),
      ),
    );
    if (choice != null) {
      try {
        await DatabaseService.instance.reconcile(
          transaction,
          ledgerType: transaction.direction == 'debit' ? 'expense' : 'income',
          ledgerId: choice,
        );
        await load();
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not match transaction: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bank reconciliation'),
      actions: [
        IconButton(onPressed: addAccount, icon: const Icon(Icons.account_balance)),
        IconButton(onPressed: addTransaction, icon: const Icon(Icons.add_card)),
      ],
    ),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (accounts.isNotEmpty) DropdownButtonFormField<int>(
          value: selected,
          items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.bankName} • ${a.name}'))).toList(),
          onChanged: (value) { setState(() => selected = value); load(); },
        ),
        const SizedBox(height: 12),
        Text('${transactions.where((t) => !t.reconciled).length} unreconciled transactions', style: Theme.of(context).textTheme.titleMedium),
        ...transactions.map((transaction) => Card(
          child: ListTile(
            title: Text(transaction.description),
            subtitle: Text('${DateFormat('dd MMM yyyy').format(transaction.date)} • ${transaction.direction.toUpperCase()} • ${transaction.reference}'),
            trailing: transaction.reconciled
              ? const Chip(label: Text('Matched'))
              : TextButton(onPressed: () => match(transaction), child: const Text('Match')),
          ),
        )),
      ],
    ),
  );
}
