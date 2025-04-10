import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/database_helper.dart';
import '../utils/exchange_rate_service.dart';
import '../utils/settings_helper.dart';

class AccountDetailScreen extends StatefulWidget {
  final int accountId;
  final String accountName;
  final String accountCurrency;

  const AccountDetailScreen({
    Key? key,
    required this.accountId,
    required this.accountName,
    required this.accountCurrency,
  }) : super(key: key);

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ExchangeRateService _exchangeRateService = ExchangeRateService();

  List<Map<String, dynamic>> transactions = [];
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  String mainCurrency = 'DOP';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final dbTransactions = await _dbHelper.getTransactionsByAccount(widget.accountId);
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';

    double income = 0.0;
    double expense = 0.0;

    List<Map<String, dynamic>> enrichedTransactions = [];

    for (var t in dbTransactions) {
      final amount = t['amount'] ?? 0.0;
      final type = t['type'] ?? 'expense';
      final currency = t['currency'] ?? 'DOP';

      final convertedAmount = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

      if (type == 'income') {
        income += convertedAmount;
      } else if (type == 'expense') {
        expense += convertedAmount;
      } else if (type == 'transfer') {
        // Tratamiento especial de transferencias si quieres separarlas
      }

      enrichedTransactions.add({
        ...t,
        'converted_amount': convertedAmount,
      });
    }

    setState(() {
      transactions = enrichedTransactions;
      totalIncome = income;
      totalExpense = expense;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = totalIncome - totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accountName, style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildSummarySection(totalBalance),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final t = transactions[index];
                final isIncome = t['type'] == 'income';
                final isExpense = t['type'] == 'expense';
                final isTransfer = t['type'] == 'transfer';
                final amount = t['converted_amount'] ?? 0.0;

                return ListTile(
                  title: Text(t['note'] ?? 'No description'),
                  subtitle: Text(DateFormat('d MMM y').format(DateTime.parse(t['date']))),
                  trailing: Text(
                    (isIncome ? '+ ' : isExpense ? '- ' : '') +
                        '${amount.toStringAsFixed(2)} $mainCurrency',
                    style: TextStyle(
                      color: isIncome
                          ? Colors.green
                          : isExpense
                          ? Colors.red
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSummarySection(double totalBalance) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('income'.tr(), totalIncome, Colors.green),
            _buildSummaryItem('expenses'.tr(), totalExpense, Colors.red),
            _buildSummaryItem('balance'.tr(), totalBalance,
                totalBalance >= 0 ? Colors.green : Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).hintColor,
            )),
        const SizedBox(height: 4),
        Text(
          '${amount.toStringAsFixed(2)} $mainCurrency',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
