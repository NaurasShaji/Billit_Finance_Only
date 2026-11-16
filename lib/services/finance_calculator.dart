import 'package:intl/intl.dart';

class FinanceCalculator {
  static String money(num value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(value);
}
