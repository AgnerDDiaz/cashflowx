import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/database_helper.dart';
import '../widgets/balance_section.dart';

class AccountDetailScreen extends StatefulWidget {
  final Map<String, dynamic> account;

  const AccountDetailScreen({Key? key, required this.account}) : super(key: key);

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final db = DatabaseHelper();
    final all = await db.getTransactions();
    final filtered = all.where((t) =>
    t['account_id'] == widget.account['id'] ||
        t['linked_account_id'] == widget.account['id']
    ).toList();
    setState(() => transactions = filtered);
  }

  @override
  Widget build(BuildContext context) {
    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      if (t['type'] == 'income' || (t['type'] == 'transfer' && t['linked_account_id'] == widget.account['id'])) {
        income += t['amount'];
      } else if (t['type'] == 'expense' || (t['type'] == 'transfer' && t['account_id'] == widget.account['id'])) {
        expense += t['amount'];
      }
    }

    double balance = income - expense;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.account['name'],
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          BalanceSection(
            totalIncome: income,
            totalExpenses: expense,
            totalBalance: balance,
            title: "account_summary".tr(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (_, index) {
                final t = transactions[index];
                final isIncome = t['type'] == 'income' || (t['type'] == 'transfer' && t['linked_account_id'] == widget.account['id']);
                final amountColor = isIncome ? AppColors.ingresoColor : AppColors.gastoColor;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Theme.of(context).cardColor,
                  child: ListTile(
                    title: Text(
                      t['note'] ?? "no_note".tr(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    subtitle: Text(
                      t['date'],
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    trailing: Text(
                      (isIncome ? '+ ' : '- ') + t['amount'].toStringAsFixed(2),
                      style: TextStyle(
                        color: amountColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
