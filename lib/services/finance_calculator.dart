import 'package:intl/intl.dart';

class FinanceCalculator {
  static String money(num value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);

  /// Percentage change from [previous] to [current]; null when there is no
  /// meaningful baseline to compare against.
  static double? percentChange(double current, double previous) {
    if (previous.abs() < 0.005) return null;
    return (current - previous) / previous.abs() * 100;
  }
}
