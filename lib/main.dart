import 'package:flutter/material.dart';
import 'package:cashflowx/utils/database_helper.dart';
import 'package:cashflowx/screen/main_screen.dart';
import 'package:cashflowx/utils/theme.dart'; // 👈 Agregado para el tema

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper().resetDatabase();

  final dbHelper = DatabaseHelper();

  // Carga los datos necesarios para toda la app
  List<Map<String, dynamic>> accounts = await dbHelper.getAccounts();
  List<Map<String, dynamic>> categories = await dbHelper.getCategories();
  List<Map<String, dynamic>> transactions = await dbHelper.getTransactions();

  runApp(MyApp(
    accounts: accounts,
    categories: categories,
    transactions: transactions,
  ));
}

class MyApp extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;

  const MyApp({
    Key? key,
    required this.accounts,
    required this.categories,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CashFlowX',
      debugShowCheckedModeBanner: false,
      theme: darkTheme, // 👈 Tema claro
      darkTheme: darkTheme, // 👈 Tema oscuro
      themeMode: ThemeMode.system, // 👈 Seguirá el modo del dispositivo
      home: MainScreen(
        accounts: accounts,
        categories: categories,
        transactions: transactions,
      ),
    );
  }
}
