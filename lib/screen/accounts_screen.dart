import 'package:easy_localization/easy_localization.dart';
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
  String mainCurrency = 'DOP'; // 🔥 Esto se leerá después desde settings.

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

  void reloadAccounts() async {
    await _loadAccounts();
  }

  Future<double> _convertToMainCurrency(double amount, String currency) async {
    if (currency == mainCurrency) {
      return amount;
    }
    final db = DatabaseHelper();
    final rate = await db.getExchangeRate(currency, mainCurrency);
    return amount * rate;
  }

  Future<double> _getTotalCapital() async {
    double total = 0.0;
    for (final account in accounts) {
      if (account['include_in_balance'] == 1 && account['balance_mode'] != 'credit') {
        final convertedBalance = await _convertToMainCurrency(account['balance'], account['currency']);
        total += convertedBalance;
      }
    }
    return total;
  }

  Future<double> _getTotalDebt() async {
    double total = 0.0;
    for (final account in accounts) {
      if (account['include_in_balance'] == 1 && account['balance_mode'] == 'credit') {
        final convertedBalance = await _convertToMainCurrency(account['balance'], account['currency']);
        total += convertedBalance;
      }
    }
    return total;
  }

  Future<double> _getTotalBalance() async {
    final capital = await _getTotalCapital();
    final debt = await _getTotalDebt();
    return capital - debt;
  }

  Future<double> _convertAmount(double amount, String currency) async {
    if (currency == mainCurrency) {
      return amount;
    }
    final db = DatabaseHelper();
    final rate = await db.getExchangeRate(currency, mainCurrency);
    return amount * rate;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> categoryMap = {};
    for (final account in accounts) {
      final category = account['category'] ?? "no_category".tr();
      if (!categoryMap.containsKey(category)) {
        categoryMap[category] = [];
      }
      categoryMap[category]!.add(account);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'accounts'.tr(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,

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
                title: "accounts_summary".tr(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: categoryMap.entries.map((entry) {
                    final category = entry.key;
                    final categoryAccounts = entry.value;
                    final visibleAccounts = categoryAccounts.where((acc) => acc['visible'] == 1).toList();

                    return FutureBuilder<double>(
                      future: _calculateCategoryTotal(categoryAccounts),
                      builder: (context, snapshot) {
                        final totalBalance = snapshot.data ?? 0.0;

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
                                  onTap: () {},
                                );
                              } else {
                                return AccountTile(
                                  name: account['name'],
                                  balance: account['balance'],
                                  currency: account['currency'],
                                  visible: account['visible'] == 1,
                                  onTap: () {},
                                );
                              }
                            }).toList(),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
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

  Future<double> _calculateCategoryTotal(List<Map<String, dynamic>> accounts) async {
    double total = 0.0;
    for (final account in accounts) {
      if (account['visible'] == 1) {
        final converted = await _convertAmount(account['balance'], account['currency']);
        total += account['balance_mode'] == 'credit' ? -converted : converted;
      }
    }
    return total;
  }
}
