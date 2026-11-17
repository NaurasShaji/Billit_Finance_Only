import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

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
    setState(() { employees = employeeRows; payments = paymentRows; loading = false; });
  }
  Future<void> addEmployee([EmployeeRecord? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final wage = TextEditingController(text: existing?.wage.toString() ?? '');
    var type = existing?.type ?? 'daily';
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, update) => AlertDialog(
      title: Text(existing == null ? 'Add employee' : 'Edit employee'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Employee name')), DropdownButtonFormField<String>(value: type, items: const [DropdownMenuItem(value: 'daily', child: Text('Daily wage')), DropdownMenuItem(value: 'monthly', child: Text('Monthly salary'))], onChanged: (value) => update(() => type = value ?? 'daily')), TextField(controller: wage, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Wage / salary amount (₹)'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(existing == null ? 'Add employee' : 'Save changes'))],
    )));
    final value = double.tryParse(wage.text);
    if (ok == true && name.text.trim().isNotEmpty && value != null && value > 0) {
      final record = EmployeeRecord(id: existing?.id, name: name.text.trim(), type: type, wage: value, attendance: existing?.attendance ?? 0, salaryPaid: existing?.salaryPaid ?? false);
      if (existing == null) await DatabaseService.instance.addEmployee(record); else await DatabaseService.instance.updateEmployee(record);
      await load();
    }
    name.dispose(); wage.dispose();
  }
  Future<void> removeEmployee(EmployeeRecord employee) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Remove employee'), content: Text('Remove ${employee.name} from the active employee list? Existing payroll history will be retained.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))]));
    if (confirmed == true) { await DatabaseService.instance.archiveEmployee(employee.id!); await load(); }
  }
  Future<void> pay(EmployeeRecord employee) async {
    final controller = TextEditingController(text: employee.wage.toStringAsFixed(2));
    final now = DateTime.now();
    final period = employee.type == 'daily' ? DateFormat('yyyy-MM-dd').format(now) : DateFormat('yyyy-MM').format(now);
    if (payments.any((payment) => payment.employeeId == employee.id && payment.period == period)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment already recorded for this period.'))); controller.dispose(); return; }
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text('Pay ${employee.name}'), content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment amount (₹)')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm payment'))]));
    final amount = double.tryParse(controller.text);
    if (ok == true && amount != null && amount > 0) { await DatabaseService.instance.addPayroll(PayrollPayment(id: null, employeeId: employee.id!, date: now, period: period, amount: amount, type: employee.type)); await load(); }
    controller.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final monthlyTotal = payments.where((p) => p.period == month).fold<double>(0, (s,p) => s+p.amount);
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: addEmployee, icon: const Icon(Icons.person_add), label: const Text('Add employee')),
      body: loading ? const Center(child: CircularProgressIndicator()) : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: ListView(padding: const EdgeInsets.all(16), children: [
        LayoutBuilder(builder: (context, box) { final count = box.maxWidth > 700 ? 2 : 1; return Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: count == 1 ? box.maxWidth : (box.maxWidth-12)/2, child: StatCard(title: 'Payroll this month', value: FinanceCalculator.money(monthlyTotal), icon: Icons.payments_outlined, color: AppColors.brand)), SizedBox(width: count == 1 ? box.maxWidth : (box.maxWidth-12)/2, child: StatCard(title: 'Active employees', value: '${employees.length}', icon: Icons.groups_outlined, color: Colors.indigo))]); }),
        const SectionHeader('Employee list'),
        if (employees.isEmpty) const EmptyState(title: 'No employees added', message: 'Add employees to start recording payroll.', icon: Icons.groups_outlined),
        ...employees.map((employee) {
          final period = employee.type == 'daily' ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : month;
          final paid = payments.any((p) => p.employeeId == employee.id && p.period == period);
          return Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.brand.withValues(alpha: .10), child: Text(employee.name.isEmpty ? '?' : employee.name[0].toUpperCase(), style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800))),
            title: Text(employee.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${employee.type == 'daily' ? 'Daily wage' : 'Monthly salary'} • ${FinanceCalculator.money(employee.wage)}'),
            trailing: Wrap(spacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [IconButton(tooltip: 'Edit employee', onPressed: () => addEmployee(employee), icon: const Icon(Icons.edit_outlined)), IconButton(tooltip: 'Remove employee', onPressed: () => removeEmployee(employee), icon: const Icon(Icons.delete_outline)), FilledButton(onPressed: paid ? null : () => pay(employee), child: Text(paid ? 'Paid' : 'Pay'))]),
          )));
        }),
        const SectionHeader('Recent payments'),
        if (payments.isEmpty) const EmptyState(title: 'No payroll payments yet', icon: Icons.payments_outlined),
        ...payments.take(25).map((payment) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)), title: Text(payment.type == 'daily' ? 'Daily wage payment' : 'Monthly salary payment'), subtitle: Text('${DateFormat('dd MMM yyyy').format(payment.date)} • ${payment.period}'), trailing: Text(FinanceCalculator.money(payment.amount), style: const TextStyle(fontWeight: FontWeight.w800))))),
      ]))),
    );
  }
}
