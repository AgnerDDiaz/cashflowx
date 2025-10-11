import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/exchange_rate_service.dart';
import '../utils/settings_helper.dart';
import '../widgets/annual_summary_view.dart';
import '../widgets/balance_section.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/transaction_item.dart';
import '../widgets/selectors/date_selector.dart';
import 'add_transaction_screen.dart';
import '../utils/app_colors.dart';

// Repos + modelos (para cargar y mapear a Map<String,dynamic>)
import '../repositories/accounts_repository.dart';
import '../repositories/categories_repository.dart';
import '../repositories/transactions_repository.dart';
import '../models/account.dart';
import '../models/category.dart' as model;
import '../models/transaction.dart';

class DashboardScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> categories;

  // Estado “sticky” entre aperturas
  static DateTime lastSelectedDate = DateTime.now();
  static String lastSelectedFilter = "monthly";

  const DashboardScreen({
    super.key,
    this.accounts = const [],
    this.categories = const [],
    this.transactions = const [],
  });

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  void reloadDashboard() {
    _loadTransactions();
  }

  late DateTime selectedDate;
  late String selectedFilter;

  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> categories = [];

  String mainCurrency = 'DOP';
  String _firstWeekday = 'monday'; // 'monday' | 'sunday'

  // repos
  final _accRepo = AccountsRepository();
  final _catRepo = CategoriesRepository();
  final _txRepo = TransactionsRepository();

  @override
  void initState() {
    super.initState();
    selectedDate = DashboardScreen.lastSelectedDate;
    selectedFilter = DashboardScreen.lastSelectedFilter;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';
    _firstWeekday = await SettingsHelper().getFirstWeekday();

    // Cuentas
    final accs = await _accRepo.getAll();
    accounts = accs.map<Map<String, dynamic>>((Account a) => a.toMap()).toList();

    // Categorías
    final cats = await _catRepo.getAll();
    categories = cats.map<Map<String, dynamic>>((model.Category c) => c.toMap()).toList();

    // Transacciones (filtradas por rango seleccionado)
    await _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
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
            firsWeekday: _firstWeekday,
          ),
          FutureBuilder(
            future: _buildBalanceValues(),
            builder: (context, AsyncSnapshot<List<double>> snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final totalIncome = snapshot.data![0];
              final totalExpenses = snapshot.data![1];
              final totalBalance = snapshot.data![2];

              return BalanceSection(
                totalIncome: totalIncome,
                totalExpenses: totalExpenses,
                totalBalance: totalBalance,
                title: "balance_of".tr(args: [selectedFilter]),
                mainCurrency: mainCurrency,
              );
            },
          ),
          Expanded(
            child: (selectedFilter.toLowerCase() == "calendario" ||
                selectedFilter.toLowerCase() == "calendar")
                ? CalendarMonthView(
              selectedDate: selectedDate,
              accounts: accounts,
              categories: categories,
              transactions: transactions,
              onFilterChange: (date, filter) {
                setState(() {
                  selectedDate = date;
                  selectedFilter = filter;
                  DashboardScreen.lastSelectedDate = date;
                  DashboardScreen.lastSelectedFilter = filter;
                });
                _loadTransactions();
              },
            )
                : (selectedFilter.toLowerCase() == "anual" ||
                selectedFilter.toLowerCase() == "annual")
                ? AnnualSummaryView(
              selectedDate: selectedDate,
              accounts: accounts,
              categories: categories,
              transactions: transactions,
              onFilterChange: (date, filter) {
                setState(() {
                  selectedDate = date;
                  selectedFilter = filter;
                  DashboardScreen.lastSelectedDate = date;
                  DashboardScreen.lastSelectedFilter = filter;
                });
                _loadTransactions();
              },
            )
                : _buildTransactionList(),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTransactions() async {
    // Opcional: puedes mover el filtro a una query por fecha en el repo.
    final all = await _txRepo.all(); // List<AppTransaction>
    final maps = all.map<Map<String, dynamic>>((AppTransaction t) => t.toMap()).toList();

    setState(() {
      transactions = maps.where((t) {
        final dateStr = (t['date'] ?? '').toString();
        if (dateStr.isEmpty) return false;
        final d = DateTime.parse(dateStr);
        return _isTransactionInSelectedRange(d);
      }).toList();
    });
  }

  bool _isTransactionInSelectedRange(DateTime transactionDate) {
    // Normaliza fecha a medianoche local (evita sorpresas por horas)
    final tx = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);

    DateTime _weekStart(DateTime d) {
      final startWd = (_firstWeekday == 'sunday') ? DateTime.sunday : DateTime.monday;
      int delta = (d.weekday - startWd) % 7;
      if (delta < 0) delta += 7;
      final localMidnight = DateTime(d.year, d.month, d.day);
      return localMidnight.subtract(Duration(days: delta));
    }

    late DateTime startDate;
    late DateTime endDate;

    switch (selectedFilter.toLowerCase()) {
      case "weekly":
      case "semanal":
        startDate = _weekStart(selectedDate);
        endDate = startDate.add(const Duration(days: 7));
        break;
      case "monthly":
      case "calendar":
      case "calendario":
        startDate = DateTime(selectedDate.year, selectedDate.month, 1);
        endDate = DateTime(selectedDate.year, selectedDate.month + 1, 1);
        break;
      case "annual":
      case "anual":
        startDate = DateTime(selectedDate.year, 1, 1);
        endDate = DateTime(selectedDate.year + 1, 1, 1);
        break;
      default:
        return false;
    }

    // Inclusivo en inicio, EXCLUSIVO en fin: [startDate, endDate)
    final startsOk = !tx.isBefore(startDate);
    final endsOk = tx.isBefore(endDate);
    return startsOk && endsOk;
  }

  Future<List<double>> _buildBalanceValues() async {
    double totalIncome = 0;
    double totalExpenses = 0;

    for (final t in transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final currency = (t['currency'] ?? mainCurrency) as String;
      final converted = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

      if (t['type'] == 'income') {
        totalIncome += converted;
      } else if (t['type'] == 'expense') {
        totalExpenses += converted;
      }
    }

    final totalBalance = totalIncome - totalExpenses;
    return [totalIncome, totalExpenses, totalBalance];
  }

  Widget _buildTransactionList() {
    final Map<String, List<Map<String, dynamic>>> transactionsByDate = {};

    for (final transaction in transactions) {
      final date = (transaction['date'] ?? 'Sin fecha').toString().split(' ')[0];
      transactionsByDate.putIfAbsent(date, () => []).add(transaction);
    }

    return ListView(
      children: transactionsByDate.entries.map((entry) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  accounts: accounts,
                  categories: categories,
                ),
                settings: RouteSettings(arguments: {'date': DateTime.parse(entry.key)}),
              ),
            ).then((_) => _loadTransactions());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado por fecha
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
                    FutureBuilder<String>(
                      future: _getBalanceText(entry.value),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? '',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: snapshot.hasData ? _getBalanceColor(entry.value) : Colors.grey,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Items del día
              ...entry.value.map((transaction) {
                return TransactionItem(
                  transaction: transaction,
                  accounts: accounts,
                  categories: categories,
                  onTransactionUpdated: _loadTransactions,
                  currentAccountId: -1,
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<String> _getBalanceText(List<Map<String, dynamic>> transactions) async {
    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final currency = (t['currency'] ?? mainCurrency) as String;
      final converted = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

      if (t['type'] == 'income') {
        income += converted;
      } else if (t['type'] == 'expense') {
        expense += converted;
      }
    }

    final balance = income - expense;
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '$mainCurrency ');
    return formatter.format(balance);
  }

  Color _getBalanceColor(List<Map<String, dynamic>> transactions) {
    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      if (t['type'] == 'income') {
        income += amount;
      } else if (t['type'] == 'expense') {
        expense += amount;
      }
    }

    return (income - expense) >= 0 ? AppColors.ingresoColor : AppColors.gastoColor;
  }
}
