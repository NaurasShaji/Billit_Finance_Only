import 'package:flutter/material.dart';

const expenseCategories = [
  'Rent',
  'Utilities',
  'Transport',
  'Supplies',
  'Maintenance',
  'Salary-Monthly',
  'Salary-Daily',
  'Miscellaneous',
];

IconData categoryIcon(String category) {
  switch (category) {
    case 'Rent':
      return Icons.home_outlined;
    case 'Utilities':
      return Icons.bolt_outlined;
    case 'Transport':
      return Icons.local_shipping_outlined;
    case 'Supplies':
      return Icons.inventory_2_outlined;
    case 'Maintenance':
      return Icons.build_outlined;
    case 'Salary-Monthly':
    case 'Salary-Daily':
      return Icons.badge_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

class FinanceUi {
  static Future<bool> confirm(BuildContext context, String title, {String confirmLabel = 'Confirm'}) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _ConfirmPage(title: title, confirmLabel: confirmLabel),
    ));
    return result ?? false;
  }
}
class _ConfirmPage extends StatelessWidget {
  const _ConfirmPage({required this.title, required this.confirmLabel});
  final String title, confirmLabel;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirm action')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel))),
          ]),
        ],
      )),
    )),
  );
}
Future<double?> showAmountDialog(BuildContext context, {
  required String title, String label = 'Amount', double initial = 0,
  String confirmLabel = 'Confirm', bool allowZero = false,
}) => Navigator.of(context).push<double>(MaterialPageRoute(builder: (_) => _AmountEntryPage(
  title: title, label: label, initial: initial, confirmLabel: confirmLabel, allowZero: allowZero,
)));
class _AmountEntryPage extends StatefulWidget {
  const _AmountEntryPage({required this.title, required this.label, required this.initial, required this.confirmLabel, required this.allowZero});
  final String title, label, confirmLabel;
  final double initial;
  final bool allowZero;
  @override
  State<_AmountEntryPage> createState() => _AmountEntryPageState();
}
class _AmountEntryPageState extends State<_AmountEntryPage> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial > 0 ? widget.initial.toStringAsFixed(2) : '');
  String? _error;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  void _submit() {
    final raw = _controller.text.trim();
    final value = raw.isEmpty && widget.allowZero ? 0.0 : double.tryParse(raw);
    if (value == null || value < 0 || (!widget.allowZero && value <= 0)) { setState(() => _error = 'Enter a valid amount'); return; }
    Navigator.pop(context, value);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [TextButton(onPressed: _submit, child: Text(widget.confirmLabel))]),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _controller, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: widget.label, prefixText: '₹ ', errorText: _error), onSubmitted: (_) => _submit()),
          const SizedBox(height: 20),
          FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
        ],
      )),
    )),
  );
}
