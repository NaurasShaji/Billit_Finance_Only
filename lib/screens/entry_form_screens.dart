import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

const _expenseCategories = ['Rent', 'Utilities', 'Transport', 'Supplies', 'Maintenance', 'Salary-Monthly', 'Salary-Daily', 'Miscellaneous'];

class IncomeEntryPage extends StatefulWidget {
  const IncomeEntryPage({super.key});
  @override
  State<IncomeEntryPage> createState() => _IncomeEntryPageState();
}
class _IncomeEntryPageState extends State<IncomeEntryPage> {
  final _key = GlobalKey<FormState>();
  final _sale = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _paid = TextEditingController(text: '0');
  final _description = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'cash';
  bool _saving = false;
  double get _saleValue => double.tryParse(_sale.text) ?? 0;
  double get _costValue => double.tryParse(_cost.text) ?? 0;
  double get _paidValue => double.tryParse(_paid.text) ?? 0;
  @override
  void dispose() { _sale.dispose(); _cost.dispose(); _paid.dispose(); _description.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.addIncome(
        IncomeRecord(date: _date, amount: _saleValue, costAmount: _costValue, description: _description.text.trim()),
        payments: _paidValue > 0 ? [IncomePayment(incomeId: 0, date: _date, method: _method, amount: _paidValue)] : [],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save income: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add sale / income'), actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))]),
    body: ResponsiveBody(maxWidth: 760, child: Form(key: _key, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Record a sale', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
      const SizedBox(height: 5),
      const Text('Enter the sale value, stock cost and amount received. The unpaid balance is calculated automatically.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Sale details'),
        TextFormField(controller: _sale, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sale total', prefixText: '₹ '), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n <= 0 ? 'Enter a sale amount greater than zero' : null; }, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        TextFormField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cost of goods sold', prefixText: '₹ ', helperText: 'Use 0 when no stock cost applies'), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n < 0 ? 'Enter a valid cost' : n > _saleValue ? 'Cost cannot exceed the sale total' : null; }, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description / bill reference', prefixIcon: Icon(Icons.receipt_long_outlined))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }, icon: const Icon(Icons.calendar_today_outlined), label: Text(DateFormat('dd MMM yyyy').format(_date))),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Payment received'),
        TextFormField(controller: _paid, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Collected now', prefixText: '₹ '), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n < 0 ? 'Enter a valid received amount' : n > _saleValue ? 'Received amount cannot exceed sale total' : null; }, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _method, decoration: const InputDecoration(labelText: 'Payment method'), items: const ['cash', 'upi', 'card', 'bank', 'other'].map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase()))).toList(), onChanged: (v) => setState(() => _method = v ?? 'cash')),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)), child: Column(children: [
          FinanceUiRow(label: 'Gross profit', value: _saleValue - _costValue),
          FinanceUiRow(label: 'Outstanding balance', value: (_saleValue - _paidValue).clamp(0, double.infinity), emphasize: true),
        ])),
      ]))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save income entry')),
    ]))),
  );
}

class ExpenseEntryPage extends StatefulWidget {
  const ExpenseEntryPage({super.key, this.existing});
  final ExpenseRecord? existing;
  @override
  State<ExpenseEntryPage> createState() => _ExpenseEntryPageState();
}
class _ExpenseEntryPageState extends State<ExpenseEntryPage> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _customCategory;
  late String _category;
  late DateTime _date;
  bool _saving = false;
  bool _custom = false;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(text: e?.amount.toString() ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _category = e?.category ?? _expenseCategories.last;
    _custom = !_expenseCategories.contains(_category);
    _customCategory = TextEditingController(text: _custom ? _category : '');
    _date = e?.date ?? DateTime.now();
  }
  @override
  void dispose() { _amount.dispose(); _description.dispose(); _customCategory.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final record = ExpenseRecord(id: widget.existing?.id, date: _date, category: _custom ? _customCategory.text.trim() : _category, amount: double.parse(_amount.text), description: _description.text.trim());
      if (widget.existing == null) { await DatabaseService.instance.addExpense(record); } else { await DatabaseService.instance.updateExpense(record); }
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save expense: $e'))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.existing == null ? 'Add expense' : 'Edit expense'), actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))]),
    body: ResponsiveBody(maxWidth: 760, child: Form(key: _key, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(widget.existing == null ? 'New expense' : 'Update expense', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
      const SizedBox(height: 5),
      const Text('Capture the category, amount and date so reports stay accurate.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        DropdownButtonFormField<String>(value: _custom ? 'Other' : _category, decoration: const InputDecoration(labelText: 'Expense category'), items: [..._expenseCategories, 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { _custom = v == 'Other'; if (!_custom) _category = v ?? _expenseCategories.last; })),
        if (_custom) ...[const SizedBox(height: 12), TextFormField(controller: _customCategory, decoration: const InputDecoration(labelText: 'Custom category'), validator: (v) => _custom && (v == null || v.trim().isEmpty) ? 'Enter a category name' : null)],
        const SizedBox(height: 12),
        TextFormField(controller: _amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n <= 0 ? 'Enter an amount greater than zero' : null; }),
        const SizedBox(height: 12),
        TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_outlined))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100); if (d != null) setState(() => _date = d); }, icon: const Icon(Icons.calendar_today_outlined), label: Text(DateFormat('dd MMM yyyy').format(_date))),
      ]))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save expense')),
    ]))),
  );
}

class EmployeeEntryPage extends StatefulWidget {
  const EmployeeEntryPage({super.key, this.existing});
  final EmployeeRecord? existing;
  @override
  State<EmployeeEntryPage> createState() => _EmployeeEntryPageState();
}
class _EmployeeEntryPageState extends State<EmployeeEntryPage> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _wage;
  late String _type;
  bool _saving = false;
  @override
  void initState() { super.initState(); _name = TextEditingController(text: widget.existing?.name ?? ''); _wage = TextEditingController(text: widget.existing?.wage.toString() ?? ''); _type = widget.existing?.type ?? 'daily'; }
  @override
  void dispose() { _name.dispose(); _wage.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final old = widget.existing;
      final employee = EmployeeRecord(id: old?.id, name: _name.text.trim(), type: _type, wage: double.parse(_wage.text), attendance: old?.attendance ?? 0, salaryPaid: old?.salaryPaid ?? false);
      if (old == null) { await DatabaseService.instance.addEmployee(employee); } else { await DatabaseService.instance.updateEmployee(employee); }
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save employee: $e'))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.existing == null ? 'Add employee' : 'Edit employee'), actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))]),
    body: ResponsiveBody(maxWidth: 760, child: Form(key: _key, child: ListView(padding: const EdgeInsets.all(20), children: [
      Text(widget.existing == null ? 'Employee details' : 'Update employee', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
      const SizedBox(height: 5),
      const Text('Set the employee name and wage structure. Payment history is kept separately.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        TextFormField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Employee name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.trim().isEmpty ? 'Enter an employee name' : null),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _type, decoration: const InputDecoration(labelText: 'Payment structure'), items: const [DropdownMenuItem(value: 'daily', child: Text('Daily wage')), DropdownMenuItem(value: 'monthly', child: Text('Monthly salary'))], onChanged: (v) => setState(() => _type = v ?? 'daily')),
        const SizedBox(height: 12),
        TextFormField(controller: _wage, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: _type == 'daily' ? 'Daily wage' : 'Monthly salary', prefixText: '₹ '), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n <= 0 ? 'Enter an amount greater than zero' : null; }),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)), child: Text(_type == 'daily' ? 'A payment period is recorded per calendar day. The same employee cannot be paid twice for the same day.' : 'A payment period is recorded per calendar month. The same employee cannot be paid twice for the same month.', style: const TextStyle(color: AppColors.muted))),
      ]))),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save employee')),
    ]))),
  );
}

class FinanceUiRow extends StatelessWidget {
  const FinanceUiRow({super.key, required this.label, required this.value, this.emphasize = false});
  final String label;
  final double value;
  final bool emphasize;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500))),
    Text(FinanceCalculator.money(value), style: TextStyle(fontWeight: FontWeight.w800, color: emphasize ? AppColors.brand : AppColors.ink)),
  ]));
}
