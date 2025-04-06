import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../widgets/annual_summary_view.dart';
import '../widgets/balance_section.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/transaction_item.dart';
import '../widgets/date_selector.dart';
import 'add_transaction_screen.dart';
import '../utils/app_colors.dart'; // Asegúrate que esté importado arriba




class DashboardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> categories;
  static DateTime lastSelectedDate = DateTime.now();
  static String lastSelectedFilter = "Mensual"; // en lugar de "Semanal"



  const DashboardScreen({
    Key? key,
    required this.accounts,
    required this.transactions,
    required this.categories,
  }) : super(key: key);

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  // 👇 Añadir este método para que MainScreen pueda llamarlo
  void reloadDashboard() {
    _loadTransactions();
  }
  late DateTime selectedDate;
  late String selectedFilter;

  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    selectedDate = DashboardScreen.lastSelectedDate;
    selectedFilter = DashboardScreen.lastSelectedFilter;
    _loadTransactions();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CashFlowX 💸',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

                DashboardScreen.lastSelectedDate = newDate;
                DashboardScreen.lastSelectedFilter = newFilter;
              });
              _loadTransactions();
            },

          ),
          _buildBalance(),
          Expanded(
            child: selectedFilter == "Calendario"
                ? CalendarMonthView(selectedDate: selectedDate)
                : selectedFilter == "Anual"
                ? AnnualSummaryView(
                    selectedDate: selectedDate,
                    accounts: accounts,
                    categories: categories,
                    transactions: transactions,
                  )
                : _buildTransactionList(),
          ),


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
      case 'Semanal':
        startDate = selectedDate.subtract(Duration(days: selectedDate.weekday - 1)); // Lunes
        endDate = startDate.add(const Duration(days: 7));
        break;


      case 'Mensual':
        startDate = DateTime(selectedDate.year, selectedDate.month, 1);
        endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
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
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  accounts: widget.accounts,
                  categories: widget.categories,
                ),
                settings: RouteSettings(arguments: {
                  'date': DateTime.parse(entry.key),
                }),
              ),
            ).then((_) => _loadTransactions());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      _getBalanceText(entry.value),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _getBalanceColor(entry.value),
                      ),
                    ),
                  ],
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
              const SizedBox(height: 12),
            ],
          ),
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

  String _getBalanceText(List<Map<String, dynamic>> transactions) {
    double income = transactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0.0));

    double expense = transactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0.0));

    double balance = income - expense;

    return "\$${balance.toStringAsFixed(2)}";
  }

  Color _getBalanceColor(List<Map<String, dynamic>> transactions) {
    double income = transactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0.0));

    double expense = transactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] ?? 0.0));

    return (income - expense) >= 0 ? AppColors.ingresoColor : AppColors.gastoColor;
  }

}
