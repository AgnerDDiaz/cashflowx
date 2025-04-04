import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../widgets/balance_section.dart';
import '../widgets/account_widgets.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> accounts = [];
  bool isLoading = true; // 🌀 Para mostrar el loader mientras carga

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => isLoading = true);
    final db = DatabaseHelper();
    List<Map<String, dynamic>> result = await db.getAccounts();
    await Future.delayed(const Duration(milliseconds: 300)); // Simular un pequeño delay
    setState(() {
      accounts = result;
      isLoading = false;
    });
  }

  void reloadAccounts() {
    _loadAccounts();
  }

  double _getTotalCapital() {
    return accounts
        .where((a) => a['include_in_balance'] == 1 && a['balance_mode'] != 'credit')
        .fold(0.0, (sum, a) => sum + (a['balance'] as double));
  }

  double _getTotalDebt() {
    return accounts
        .where((a) => a['include_in_balance'] == 1 && a['balance_mode'] == 'credit')
        .fold(0.0, (sum, a) => sum - (a['balance'] as double));
  }

  double _getTotalBalance() {
    return _getTotalCapital() - _getTotalDebt();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

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
      body: Column(
        children: [
          BalanceSection(
            totalIncome: _getTotalCapital(),
            totalExpenses: _getTotalDebt(),
            totalBalance: _getTotalBalance(),
            title: "Resumen de cuentas",
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAccounts, // 👈 Se actualiza al deslizar hacia abajo
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: categoryMap.entries.length,
                itemBuilder: (context, index) {
                  final entry = categoryMap.entries.elementAt(index);
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

                  return AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: Column(
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
                                // Navegar al detalle de tarjeta de crédito
                              },
                            );
                          } else {
                            return AccountTile(
                              name: account['name'],
                              balance: account['balance'],
                              currency: account['currency'],
                              visible: account['visible'] == 1,
                              onTap: () {
                                // Navegar al detalle de cuenta
                              },
                            );
                          }
                        }).toList(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
