import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../widgets/balance_section.dart';
import '../widgets/account_widgets.dart'; // 👈 nuestros widgets nuevos

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> accounts = [];
  String mainCurrency = 'DOP'; // 🔥 En el futuro lo leeremos desde Settings

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final db = DatabaseHelper();
    List<Map<String, dynamic>> result = await db.getAccounts();
    setState(() => accounts = result);
  }

  Future<double> _getTotalCapital() async {
    final db = DatabaseHelper();
    double total = 0.0;
    for (final account in accounts) {
      if (account['include_in_balance'] == 1 && account['balance_mode'] != 'credit') {
        final balance = account['balance'] as double;
        final accountCurrency = account['currency'] as String;
        final rate = await db.getExchangeRate(accountCurrency, mainCurrency);
        total += balance * rate;
      }
    }
    return total;
  }

  Future<double> _getTotalDebt() async {
    final db = DatabaseHelper();
    double total = 0.0;
    for (final account in accounts) {
      if (account['include_in_balance'] == 1 && account['balance_mode'] == 'credit') {
        final balance = account['balance'] as double;
        final accountCurrency = account['currency'] as String;
        final rate = await db.getExchangeRate(accountCurrency, mainCurrency);
        total += balance * rate;
      }
    }
    return total;
  }

  Future<double> _getTotalBalance() async {
    final capital = await _getTotalCapital();
    final debt = await _getTotalDebt();
    return capital - debt;
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar cuentas por categoría
    final Map<String, List<Map<String, dynamic>>> categoryMap = {};
    for (final account in accounts) {
      final category = account['category'] ?? 'Sin categoría';
      if (!categoryMap.containsKey(category)) {
        categoryMap[category] = [];
      }
      categoryMap[category]!.add(account);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          _getTotalCapital(),
          _getTotalDebt(),
          _getTotalBalance(),
        ]),
        builder: (context, AsyncSnapshot<List<double>> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final totalIncome = snapshot.data![0];
          final totalExpenses = snapshot.data![1];
          final totalBalance = snapshot.data![2];

          return Column(
            children: [
              BalanceSection(
                totalIncome: totalIncome,
                totalExpenses: totalExpenses,
                totalBalance: totalBalance,
                title: "Resumen de cuentas",
              ),
              Expanded(
                child: ListView(
                  children: categoryMap.entries.map((entry) {
                    final category = entry.key;
                    final categoryAccounts = entry.value;

                    final visibleAccounts = categoryAccounts.where((acc) => acc['visible'] == 1).toList();
                    final totalBalance = visibleAccounts.fold<double>(
                      0.0,
                          (sum, acc) {
                        final balance = acc['balance'] as double;
                        return acc['balance_mode'] == 'credit' ? sum - balance : sum + balance;
                      },
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AccountCategoryHeader(
                          category: category,
                          totalBalance: totalBalance,
                          isHidden: visibleAccounts.isEmpty,
                        ),
                        ...categoryAccounts.map((account) {
                          final type = account['type'];

                          if (type == 'credit') {
                            return CreditCardTile(
                              name: account['name'],
                              dueAmount: account['balance'],
                              remainingCredit: (account['max_credit'] ?? 0) - (account['balance'] ?? 0),
                              currency: account['currency'],
                              visible: account['visible'] == 1,
                              onTap: () {
                                // 🔥 Navegar al detalle de tarjeta de crédito
                              },
                            );
                          } else {
                            return AccountTile(
                              name: account['name'],
                              balance: account['balance'],
                              currency: account['currency'],
                              visible: account['visible'] == 1,
                              onTap: () {
                                // 🔥 Navegar al detalle de cuenta normal
                              },
                            );
                          }
                        }).toList(),
                        const SizedBox(height: 12),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
