import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'payroll_screen.dart';
import 'reports_screen.dart';
import 'backup_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<AppShell> createState() => _AppShellState();
}
class _AppShellState extends State<AppShell> {
  int index = 0;
  late final pages = const [DashboardScreen(), ExpensesScreen(), PayrollScreen(), ReportsScreen(), BackupScreen()];
  static const destinations = [
    NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Overview'),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Expenses'),
    NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Payroll'),
    NavigationDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: 'Reports'),
    NavigationDestination(icon: Icon(Icons.cloud_outlined), selectedIcon: Icon(Icons.cloud), label: 'Backup'),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: destinations,
    ),
  );
}
