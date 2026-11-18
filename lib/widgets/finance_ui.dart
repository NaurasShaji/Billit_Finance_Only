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
  static Future<bool> confirm(
    BuildContext context,
    String title, {
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Asks for a single amount. Returns null when cancelled.
Future<double?> showAmountDialog(
  BuildContext context, {
  required String title,
  String label = 'Amount',
  double initial = 0,
  String confirmLabel = 'Confirm',
  bool allowZero = false,
}) => showDialog<double>(
  context: context,
  builder: (_) => _AmountDialog(
    title: title,
    label: label,
    initial: initial,
    confirmLabel: confirmLabel,
    allowZero: allowZero,
  ),
);

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
    required this.allowZero,
  });
  final String title;
  final String label;
  final double initial;
  final String confirmLabel;
  final bool allowZero;
  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial > 0 ? widget.initial.toStringAsFixed(2) : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.trim();
    final double? value = raw.isEmpty && widget.allowZero
        ? 0.0
        : double.tryParse(raw);
    if (value == null || value < 0 || (!widget.allowZero && value <= 0)) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: '₹ ',
        errorText: _error,
      ),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
    ],
  );
}
