import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // ⬅️ solo kDebugMode
import 'package:easy_localization/easy_localization.dart';

import 'utils/database_helper.dart';
import 'utils/theme.dart';
import 'screen/main_screen.dart';

// Repos & Models (para cargar datos iniciales sin tocar pantallas aún)
import 'repositories/accounts_repository.dart';
import 'repositories/categories_repository.dart';
import 'repositories/transactions_repository.dart';
import 'models/account.dart';
import 'models/category.dart' as model; // ⬅️ evita colisiones si alguna vez importas foundation entero
import 'models/transaction.dart';

// 🚧 Solo para desarrollo: borrar BD al arrancar si lo necesitas
const bool kResetDbOnBoot = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (kResetDbOnBoot && kDebugMode) {
    await DatabaseHelper().resetDatabase();
  }

  // Fuerza la inicialización/migraciones y (en debug) los seeds de prueba
  await DatabaseHelper().database;

  // Cargar datos con repos (y pasarlos como Map para no romper MainScreen todavía)
  final accounts = await _loadAccountsAsMaps();
  final categories = await _loadCategoriesAsMaps();
  final transactions = await _loadTransactionsAsMaps();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es')],
      path: 'assets/l10n',
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
      // Easy Localization
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}

// ==============================
// Loaders temporales (pueden irse cuando migremos las pantallas a repos/services)
// ==============================
Future<List<Map<String, dynamic>>> _loadAccountsAsMaps() async {
  final repo = AccountsRepository();
  final list = await repo.getAll(); // List<Account>
  return list.map<Map<String, dynamic>>((Account a) => a.toMap()).toList();
}

Future<List<Map<String, dynamic>>> _loadCategoriesAsMaps() async {
  final repo = CategoriesRepository();
  final list = await repo.getAll(); // List<model.Category>
  return list.map<Map<String, dynamic>>((model.Category c) => c.toMap()).toList();
}

Future<List<Map<String, dynamic>>> _loadTransactionsAsMaps() async {
  final repo = TransactionsRepository();
  final list = await repo.all(); // List<AppTransaction>
  return list.map<Map<String, dynamic>>((AppTransaction t) => t.toMap()).toList();
}
