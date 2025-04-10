import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../widgets/account_widgets.dart';
import '../widgets/balance_section.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> accounts = [];
  Map<String, double> categoryTotals = {};


  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accs = await _dbHelper.getAccounts();
    setState(() {
      accounts = accs;
      _calculateCategoryTotals();
    });
  }

  void reloadAccounts() {
    _loadAccounts();
  }


  void _calculateCategoryTotals() {
    final Map<String, double> totals = {};

    for (var account in accounts) {
      final String category = account['category'] ?? 'Otros';
      final double balance = account['balance'] ?? 0.0;
      totals[category] = (totals[category] ?? 0.0) + balance;
    }

    setState(() {
      categoryTotals = totals;
    });
  }

  double _calculateTotalBalance() {
    double total = 0.0;
    for (var account in accounts) {
      total += account['balance'] ?? 0.0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final mainCurrency = accounts.isNotEmpty ? accounts.first['currency'] : 'DOP';
    final totalIncome = accounts.where((a) => a['balance'] != null && a['balance'] >= 0).fold(0.0, (sum, a) => sum + (a['balance'] as double));
    final totalExpenses = accounts.where((a) => a['balance'] != null && a['balance'] < 0).fold(0.0, (sum, a) => sum + (a['balance'] as double));

    return Scaffold(
      appBar: AppBar(
        title: Text('Cuentas', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAccounts,
        child: ListView(
          children: [
            BalanceSection(
              totalIncome: totalIncome,
              totalExpenses: totalExpenses,
              totalBalance: _calculateTotalBalance(),
              mainCurrency: mainCurrency,
            ),
            const SizedBox(height: 10),
            ...categoryTotals.keys.map((category) {
              final catAccounts = accounts.where((a) => a['category'] == category).toList();
              final catTotal = categoryTotals[category] ?? 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AccountCategoryHeader(
                    category: category,
                    totalBalance: catTotal,
                  ),
                  ...catAccounts.map((account) {
                    return AccountTile(
                      name: account['name'],
                      balance: account['balance'],
                      currency: account['currency'],
                      visible: account['visible'] == 1,
                      onTap: () {
                        // Aquí puedes navegar a la pantalla de detalle de la cuenta
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
