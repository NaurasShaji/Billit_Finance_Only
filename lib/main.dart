import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'services/database_service.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  await DatabaseService.instance.database;
  runApp(const BillitFinanceApp());
}

class BillitFinanceApp extends StatelessWidget {
  const BillitFinanceApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Billit Finance',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const _AuthGate(),
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<_AuthGate> {
  bool authenticated = false;
  @override
  Widget build(BuildContext context) => authenticated
      ? AppShell(onLogout: () => setState(() => authenticated = false))
      : LoginScreen(onAuthenticated: () => setState(() => authenticated = true));
}
