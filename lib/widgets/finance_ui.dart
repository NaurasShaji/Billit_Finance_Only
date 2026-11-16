import 'package:flutter/material.dart';
import '../services/finance_calculator.dart';

class FinanceUi {
  static Widget amountField(
    TextEditingController controller, {
    String label = 'Amount (₹)',
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.currency_rupee),
      ),
    );
  }

  static Future<bool> confirm(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  static Widget row(String name, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            FinanceCalculator.money(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget empty(String message) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.blueGrey),
        ),
      ),
    );
  }
}
