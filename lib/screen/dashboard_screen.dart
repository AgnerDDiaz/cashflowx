import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../widgets/balance_section.dart';
import '../widgets/transaction_item.dart';
import '../widgets/date_selector.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> categories;
  final VoidCallback? onRefresh;

  const DashboardScreen({
    Key? key,
    required this.accounts,
    required this.transactions,
    required this.categories,
    this.onRefresh,
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime selectedDate = DateTime.now();
  String selectedFilter = "Semanal";
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    widget.onRefresh?.call();
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CashFlowX 💸', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 4,)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          DateSelector(
            initialDate: selectedDate,
            initialFilter: selectedFilter,
            onDateChanged: (newDate, newFilter) {
              setState(() {
                selectedDate = newDate;
                selectedFilter = newFilter;
              });
              _loadTransactions();
            },
          ),
          _buildBalance(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  Future<void> _loadTransactions() async {
    List<Map<String, dynamic>> data = await DatabaseHelper().getTransactions();

    setState(() {
      transactions = data.where((t) {
        DateTime transactionDate = DateTime.parse(t['date']);
        return _isTransactionInSelectedRange(transactionDate);
      }).toList();
    });
  }

  bool _isTransactionInSelectedRange(DateTime transactionDate) {
    DateTime startDate;
    DateTime endDate;

    switch (selectedFilter) {
      case 'Diaria':
        startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        endDate = startDate.add(const Duration(days: 1));
        break;
      case 'Semanal':
        startDate = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
        endDate = startDate.add(const Duration(days: 6));
        break;
      case 'Calendario':
        startDate = DateTime(selectedDate.year, selectedDate.month, 1);
        endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
        break;
      case 'Anual':
        startDate = DateTime(selectedDate.year, 1, 1);
        endDate = DateTime(selectedDate.year + 1, 1, 1);
        break;
      default:
        return false;
    }

    return transactionDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        transactionDate.isBefore(endDate);
  }

  Widget _buildBalance() {
    double totalIncome = transactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0.0));

    double totalExpenses = transactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0.0));

    double totalBalance = totalIncome - totalExpenses;

    return BalanceSection(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalBalance: totalBalance,
      title: "Balance de $selectedFilter",
    );
  }

  Widget _buildTransactionList() {
    Map<String, List<Map<String, dynamic>>> transactionsByDate = {};

    for (var transaction in transactions) {
      String date = (transaction['date'] ?? 'Sin fecha').split(' ')[0];
      if (!transactionsByDate.containsKey(date)) {
        transactionsByDate[date] = [];
      }
      transactionsByDate[date]!.add(transaction);
    }

    return ListView(
      children: transactionsByDate.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                entry.key,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ),
            ...entry.value.map((transaction) {
              String categoryName = _getCategoryName(transaction['category_id']);
              String accountName = _getAccountName(transaction['account_id']);
              String linkedAccountName = transaction['linked_account_id'] != null
                  ? _getAccountName(transaction['linked_account_id'])
                  : '';

              if (transaction['type'] == 'transfer') {
                categoryName = "Transferencia";
                accountName = "$accountName → $linkedAccountName";
              }

              return TransactionItem(
                transaction: transaction,
                accounts: widget.accounts,
                categories: widget.categories,
                onTransactionUpdated: _loadTransactions,
              );
            }).toList(),
          ],
        );
      }).toList(),
    );
  }

  String _getCategoryName(int? categoryId) {
    if (categoryId == null) return "Desconocida";
    var category = widget.categories.firstWhere(
            (cat) => cat['id'] == categoryId, orElse: () => {'name': 'Desconocida'});
    return category['name'];
  }

  String _getAccountName(int? accountId) {
    if (accountId == null) return "Transferencia";
    var account = widget.accounts.firstWhere(
            (acc) => acc['id'] == accountId, orElse: () => {'name': 'Desconocida'});
    return account['name'];
  }
}
