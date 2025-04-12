import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/settings_helper.dart';
import '../utils/exchange_rate_service.dart';
import '../widgets/account_widgets.dart';
import '../widgets/balance_section.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  List<Map<String, dynamic>> accounts = [];
  String mainCurrency = 'DOP';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';
    await _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final db = DatabaseHelper();
    List<Map<String, dynamic>> result = await db.getAccounts();
    setState(() => accounts = result);
  }

  void reloadAccounts() {
    _loadAccounts();
  }

  Future<double> _convertAmount(double amount, String currency) async {
    return await ExchangeRateService.localConvert(amount, currency, mainCurrency);
  }


  Future<List<double>> _calculateGeneralTotals() async {
    double income = 0.0;
    double expenses = 0.0;

    for (final account in accounts) {
      if (account['visible'] == 1 && account['include_in_balance'] == 1) {
        final balance = (account['balance'] as num).toDouble();
        final converted = await _convertAmount(balance, account['currency'] as String);

        final adjusted = converted; // No alterar el signo manualmente

        if (adjusted >= 0) {
          income += adjusted;
        } else {
          expenses += adjusted;
        }
      }
    }

    final totalBalance = income + expenses;
    return [income, expenses, totalBalance];
  }

  Future<double> _calculateCategoryTotal(List<Map<String, dynamic>> categoryAccounts) async {
    double total = 0.0;

    for (final account in categoryAccounts) {
      if (account['visible'] == 1) {
        final balance = (account['balance'] as num).toDouble();
        final converted = await _convertAmount(balance, account['currency'] as String);

        total += converted;
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> categoryMap = {};
    for (final account in accounts) {
      final category = account['category'] ?? 'no_category'.tr();
      categoryMap.putIfAbsent(category, () => []).add(account);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('accounts'.tr(), style: Theme.of(context).textTheme.titleLarge),
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
      body: RefreshIndicator(
        onRefresh: _loadAccounts,
        child: ListView(
          children: [
            FutureBuilder<List<double>>(
              future: _calculateGeneralTotals(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ));
                }

                final totalIncome = snapshot.data![0];
                final totalExpenses = snapshot.data![1];
                final totalBalance = snapshot.data![2];

                return BalanceSection(
                  totalIncome: totalIncome,
                  totalExpenses: totalExpenses,
                  totalBalance: totalBalance,
                  title: "accounts_summary".tr(),
                  mainCurrency: mainCurrency,
                );
              },
            ),
            const SizedBox(height: 8),
            ...categoryMap.entries.map((entry) {
              final category = entry.key;
              final categoryAccounts = entry.value;
              final visibleAccounts = categoryAccounts.where((acc) => acc['visible'] == 1).toList();

              return FutureBuilder<double>(
                future: _calculateCategoryTotal(categoryAccounts),
                builder: (context, snapshot) {
                  final categoryBalance = snapshot.data ?? 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AccountCategoryHeader(
                        category: category,
                        totalBalance: categoryBalance,
                        isHidden: visibleAccounts.isEmpty,
                        mainCurrency: mainCurrency,
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
          ],
        ),
      ),
    );
  }
}
