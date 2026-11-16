import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<EmployeeRecord> employees = [];
  List<PayrollPayment> payments = [];
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final employeeRows = await DatabaseService.instance.employees();
    final paymentRows = await DatabaseService.instance.payroll();
    if (!mounted) return;
    setState(() {
      employees = employeeRows;
      payments = paymentRows;
      loading = false;
    });
  }

  Future<void> addEmployee([EmployeeRecord? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final wage = TextEditingController(text: existing?.wage.toString() ?? '');
    var type = existing?.type ?? 'daily';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, update) => AlertDialog(
        title: Text(existing == null ? 'Add employee' : 'Edit employee'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Employee name')),
          DropdownButtonFormField<String>(
            value: type,
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily wage')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly salary')),
            ],
            onChanged: (value) => update(() => type = value ?? 'daily'),
          ),
          TextField(controller: wage, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Wage / salary amount (₹)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
        ],
      )),
    );
    final value = double.tryParse(wage.text);
    if (ok == true && name.text.trim().isNotEmpty && value != null && value > 0) {
      final record = EmployeeRecord(id: existing?.id, name: name.text.trim(), type: type, wage: value, attendance: existing?.attendance ?? 0, salaryPaid: existing?.salaryPaid ?? false);
      if (existing == null) { await DatabaseService.instance.addEmployee(record); }
      else { await DatabaseService.instance.updateEmployee(record); }
      await load();
    }
    name.dispose(); wage.dispose();
  }

  Future<void> removeEmployee(EmployeeRecord employee) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remove employee'),
      content: Text('Remove ${employee.name} from the active employee list? Existing payroll history will be retained.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))],
    ));
    if (confirmed == true) { await DatabaseService.instance.archiveEmployee(employee.id!); await load(); }
  }

  Future<void> pay(EmployeeRecord employee) async {
    final controller = TextEditingController(text: employee.wage.toStringAsFixed(2));
    final now = DateTime.now();
    final period = employee.type == 'daily'
        ? DateFormat('yyyy-MM-dd').format(now)
        : DateFormat('yyyy-MM').format(now);
    if (payments.any((payment) => payment.employeeId == employee.id && payment.period == period)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment already recorded for this period.')),
      );
      controller.dispose();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pay ${employee.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Payment amount (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm payment')),
        ],
      ),
    );
    final amount = double.tryParse(controller.text);
    if (ok == true && amount != null && amount > 0) {
      await DatabaseService.instance.addPayroll(PayrollPayment(
        id: null,
        employeeId: employee.id!,
        date: now,
        period: period,
        amount: amount,
        type: employee.type,
      ));
      // Payroll has its own ledger; do not duplicate the same payment in expenses.
      await load();
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final monthlyTotal = payments
        .where((payment) => payment.period == month)
        .fold<double>(0, (sum, payment) => sum + payment.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll'), actions: [
        IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEmployee,
        icon: const Icon(Icons.person_add),
        label: const Text('Add employee'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Expanded(child: Text('Payroll this month', style: TextStyle(fontWeight: FontWeight.w700))),
                  Text(FinanceCalculator.money(monthlyTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ]),
              )),
              Text('${employees.length} active employees', style: Theme.of(context).textTheme.titleMedium),
              ...employees.map((employee) {
                final today = DateTime.now();
                final period = employee.type == 'daily'
                    ? DateFormat('yyyy-MM-dd').format(today)
                    : month;
                final paid = payments.any((payment) =>
                    payment.employeeId == employee.id && payment.period == period);
                return Card(child: ListTile(
                  leading: CircleAvatar(child: Text(employee.name.isEmpty ? '?' : employee.name[0].toUpperCase())),
                  title: Text(employee.name),
                  subtitle: Text('${employee.type == 'daily' ? 'Daily wage' : 'Monthly salary'} • ${FinanceCalculator.money(employee.wage)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Edit employee', onPressed: () => addEmployee(employee), icon: const Icon(Icons.edit_outlined)),
                    IconButton(tooltip: 'Remove employee', onPressed: () => removeEmployee(employee), icon: const Icon(Icons.delete_outline)),
                    FilledButton(onPressed: paid ? null : () => pay(employee), child: Text(paid ? 'Paid' : 'Pay')),
                  ]),
                ));
              }),
              const Divider(),
              Text('Recent payments', style: Theme.of(context).textTheme.titleMedium),
              ...payments.take(25).map((payment) => ListTile(
                title: Text(payment.type == 'daily' ? 'Daily wage payment' : 'Monthly salary payment'),
                subtitle: Text('${DateFormat('dd MMM yyyy').format(payment.date)} • ${payment.period}'),
                trailing: Text(FinanceCalculator.money(payment.amount)),
              )),
            ]),
    );
  }
}
