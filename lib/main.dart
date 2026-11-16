import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'screens/app_shell.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.database;
  runApp(const BillitFinanceApp());
}
class BillitFinanceApp extends StatelessWidget {
  const BillitFinanceApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title:'Billit Finance', debugShowCheckedModeBanner:false,
    theme:ThemeData(
      useMaterial3:true,
      colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF087E70)),
      scaffoldBackgroundColor:const Color(0xFFF5F7F8),
      appBarTheme:const AppBarTheme(backgroundColor:Color(0xFFF5F7F8),foregroundColor:Color(0xFF14232B),elevation:0),
      cardTheme:CardThemeData(elevation:0,color:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:const BorderSide(color:Color(0xFFE5EAED)))),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(13))),
    ),
    home:const AppShell(),
  );
}
