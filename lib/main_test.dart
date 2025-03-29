import 'package:flutter/material.dart';
import 'utils/database_helper.dart';
import 'screen/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔴 Elimina la base de datos manualmente para reiniciar desde cero
  await DatabaseHelper().resetDatabase();

  final DatabaseHelper dbHelper = DatabaseHelper();

  // 🔄 Recarga datos desde la BD vacía (forzará la recreación con datos por defecto)
  List<Map<String, dynamic>> accounts = await dbHelper.getAccounts();
  List<Map<String, dynamic>> transactions = await dbHelper.getTransactions();
  List<Map<String, dynamic>> categories = await dbHelper.getCategories();

  runApp(MyApp(accounts: accounts, transactions: transactions, categories: categories));
}


class MyApp extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> categories;

  const MyApp({
    Key? key,
    required this.accounts,
    required this.transactions,
    required this.categories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CashFlowX',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DashboardScreen(
        accounts: accounts,
        transactions: transactions,
        categories: categories, // ✅ Se agrega el parámetro requerido
      ),
    );
  }
}
