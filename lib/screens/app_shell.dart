import 'package:flutter/material.dart';
import 'dashboard_screen.dart';import 'expenses_screen.dart';import 'payroll_screen.dart';import 'bank_screen.dart';import 'costs_screen.dart';
class AppShell extends StatefulWidget{const AppShell({super.key});@override State<AppShell> createState()=>_AppShellState();}
class _AppShellState extends State<AppShell>{
 int index=0;final pages=const [DashboardScreen(),ExpensesScreen(),PayrollScreen(),BankScreen(),CostsScreen()];
 static const destinations=[NavigationDestination(icon:Icon(Icons.space_dashboard_outlined),selectedIcon:Icon(Icons.space_dashboard),label:'Overview'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'Expenses'),NavigationDestination(icon:Icon(Icons.groups_outlined),selectedIcon:Icon(Icons.groups),label:'Payroll'),NavigationDestination(icon:Icon(Icons.account_balance_outlined),selectedIcon:Icon(Icons.account_balance),label:'Bank'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),selectedIcon:Icon(Icons.inventory_2),label:'COGS')];
 @override Widget build(BuildContext c)=>Scaffold(body:IndexedStack(index:index,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:destinations));
}
