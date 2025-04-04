import 'package:flutter/material.dart';
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
      appBar: AppBar(title: Text(widget.account['name'])),
      body: Column(
        children: [
          BalanceSection(
            totalIncome: income,
            totalExpenses: expense,
            totalBalance: balance,
            title: "Resumen de cuenta",
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (_, index) {
                final t = transactions[index];
                final isIncome = t['type'] == 'income' || (t['type'] == 'transfer' && t['linked_account_id'] == widget.account['id']);
                return ListTile(
                  title: Text(t['note'] ?? 'Sin nota'),
                  subtitle: Text(t['date']),
                  trailing: Text(
                    (isIncome ? '+' : '-') + t['amount'].toString(),
                    style: TextStyle(color: isIncome ? Colors.green : Colors.red),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
