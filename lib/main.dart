import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 👈 Agregado
import 'package:cashflowx/utils/database_helper.dart';
import 'package:cashflowx/screen/main_screen.dart';
import 'package:cashflowx/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized(); // 👈 Muy importante

  await DatabaseHelper().resetDatabase();

  final dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> accounts = await dbHelper.getAccounts();
  List<Map<String, dynamic>> categories = await dbHelper.getCategories();
  List<Map<String, dynamic>> transactions = await dbHelper.getTransactions();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('es')
      ],
      path: 'assets/l10n', // 👈 Aquí están los JSON
      fallbackLocale: const Locale('en'),
      child: MyApp(
        accounts: accounts,
        categories: categories,
        transactions: transactions,
      ),
    ),
  );
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
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: MainScreen(
        accounts: accounts,
        categories: categories,
        transactions: transactions,
      ),
      localizationsDelegates: context.localizationDelegates, // 👈 Easy localization
      supportedLocales: context.supportedLocales, // 👈 Easy localization
      locale: context.locale, // 👈 Easy localization
    );
  }
}
