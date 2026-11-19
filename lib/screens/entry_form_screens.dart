import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../models/finance_models.dart';
import '../services/database_service.dart';
import '../services/finance_calculator.dart';
import '../theme/app_theme.dart';
import '../widgets/finance_ui.dart';
import '../widgets/ui_kit.dart';

const _decimal = TextInputType.numberWithOptions(decimal: true);

class IncomeEntryPage extends StatefulWidget {
  const IncomeEntryPage({super.key});
  @override
  State<IncomeEntryPage> createState() => _IncomeEntryPageState();
}

class _IncomeEntryPageState extends State<IncomeEntryPage> {
  final _key = GlobalKey<FormState>();
  final _sale = TextEditingController();
  final _cost = TextEditingController();
  final _paid = TextEditingController();
  final _description = TextEditingController();
  DateTime _date = DateTime.now();
  String _method = 'cash';
  bool _saving = false;

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  double get _saleValue => _num(_sale);
  double get _costValue => _num(_cost);
  double get _paidValue => _num(_paid);

  @override
  void dispose() {
    _sale.dispose();
    _cost.dispose();
    _paid.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _optionalAmount(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    return n == null || n < 0 ? 'Enter a valid amount' : null;
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result?.files.single.path != null) setState(() => _receiptPath = result!.files.single.path);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DatabaseService.instance.addIncome(
        IncomeRecord(
          date: _date,
          amount: _saleValue,
          costAmount: _costValue,
          description: _description.text.trim(),
        ),
        payments: _paidValue > 0
            ? [
                IncomePayment(
                  incomeId: 0,
                  date: _date,
                  method: _method,
                  amount: _paidValue,
                ),
              ]
            : [],
      );
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Add sale'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
    body: ResponsiveBody(
      maxWidth: 760,
      child: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _sale,
                      autofocus: true,
                      keyboardType: _decimal,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Sale total',
                        prefixText: '₹ ',
                      ),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return n == null || n <= 0
                            ? 'Enter an amount greater than zero'
                            : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cost,
                      keyboardType: _decimal,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Cost of goods',
                        hintText: '0',
                        prefixText: '₹ ',
                      ),
                      validator: _optionalAmount,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Bill reference / note',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickReceipt,
                      icon: const Icon(Icons.photo_camera_back_outlined),
                      label: Text(_receiptPath == null ? 'Attach receipt photo' : 'Change receipt photo'),
                    ),
                    if (_receiptPath != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.image_outlined),
                        title: Text(_receiptPath!.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _receiptPath = null)),
                      ),
                    DateField(
                      value: _date,
                      onChanged: (d) => setState(() => _date = d),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _paid,
                      keyboardType: _decimal,
                      decoration: const InputDecoration(
                        labelText: 'Collected now',
                        hintText: '0',
                        prefixText: '₹ ',
                      ),
                      validator: (v) {
                        final base = _optionalAmount(v);
                        if (base != null) return base;
                        return _num(_paid) > _saleValue
                            ? 'Cannot exceed the sale total'
                            : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    ActionChip(
                      avatar: const Icon(Icons.done_all, size: 18),
                      label: const Text('Paid in full'),
                      onPressed: () =>
                          setState(() => _paid.text = _sale.text.trim()),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in [
                          'cash',
                          'upi',
                          'card',
                          'bank',
                          'other',
                        ])
                          ChoiceChip(
                            label: Text(m.toUpperCase()),
                            selected: _method == m,
                            onSelected: (_) => setState(() => _method = m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.softFill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          FinanceUiRow(
                            label: 'Gross profit',
                            value: _saleValue - _costValue,
                          ),
                          FinanceUiRow(
                            label: 'Outstanding',
                            value: (_saleValue - _paidValue)
                                .clamp(0, double.infinity)
                                .toDouble(),
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Save sale'),
            ),
          ],
        ),
      ),
    ),
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
  String? _receiptPath;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(text: e?.amount.toString() ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _category = e?.category ?? expenseCategories.last;
    _custom = !expenseCategories.contains(_category);
    _customCategory = TextEditingController(text: _custom ? _category : '');
    _date = e?.date ?? DateTime.now();
    _receiptPath = e?.receiptPath;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final record = ExpenseRecord(
        id: widget.existing?.id,
        date: _date,
        category: _custom ? _customCategory.text.trim() : _category,
        amount: double.parse(_amount.text.trim()),
        description: _description.text.trim(),
        receiptPath: _receiptPath,
      );
      if (widget.existing == null) {
        await DatabaseService.instance.addExpense(record);
      } else {
        await DatabaseService.instance.updateExpense(record);
      }
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Add expense' : 'Edit expense'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
    body: ResponsiveBody(
      maxWidth: 760,
      child: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _amount,
                      autofocus: widget.existing == null,
                      keyboardType: _decimal,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                      ),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return n == null || n <= 0
                            ? 'Enter an amount greater than zero'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in expenseCategories)
                          ChoiceChip(
                            avatar: Icon(categoryIcon(c), size: 16),
                            label: Text(c),
                            selected: !_custom && _category == c,
                            onSelected: (_) => setState(() {
                              _custom = false;
                              _category = c;
                            }),
                          ),
                        ChoiceChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Other'),
                          selected: _custom,
                          onSelected: (_) => setState(() => _custom = true),
                        ),
                      ],
                    ),
                    if (_custom) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customCategory,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Category name',
                        ),
                        validator: (v) =>
                            _custom && (v == null || v.trim().isEmpty)
                            ? 'Enter a category name'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DateField(
                      value: _date,
                      onChanged: (d) => setState(() => _date = d),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Save expense'),
            ),
          ],
        ),
      ),
    ),
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
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _wage = TextEditingController(text: widget.existing?.wage.toString() ?? '');
    _type = widget.existing?.type ?? 'daily';
  }

  @override
  void dispose() {
    _name.dispose();
    _wage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final old = widget.existing;
      final employee = EmployeeRecord(
        id: old?.id,
        name: _name.text.trim(),
        type: _type,
        wage: double.parse(_wage.text.trim()),
        attendance: old?.attendance ?? 0,
        salaryPaid: old?.salaryPaid ?? false,
      );
      if (old == null) {
        await DatabaseService.instance.addEmployee(employee);
      } else {
        await DatabaseService.instance.updateEmployee(employee);
      }
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Add employee' : 'Edit employee'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
    body: ResponsiveBody(
      maxWidth: 760,
      child: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _name,
                      autofocus: widget.existing == null,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: 'daily',
                          label: Text('Daily wage'),
                        ),
                        ButtonSegment(
                          value: 'monthly',
                          label: Text('Monthly salary'),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _wage,
                      keyboardType: _decimal,
                      decoration: InputDecoration(
                        labelText: _type == 'daily'
                            ? 'Daily wage'
                            : 'Monthly salary',
                        prefixText: '₹ ',
                      ),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return n == null || n <= 0
                            ? 'Enter an amount greater than zero'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Save employee'),
            ),
          ],
        ),
      ),
    ),
  );
}

class FinanceUiRow extends StatelessWidget {
  const FinanceUiRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });
  final String label;
  final double value;
  final bool emphasize;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          FinanceCalculator.money(value),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: emphasize ? context.accent : context.ink,
          ),
        ),
      ],
    ),
  );
}
