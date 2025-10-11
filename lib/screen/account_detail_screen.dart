import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_colors.dart';
import '../services/exchange_rate_service.dart';
import '../utils/settings_helper.dart';

import '../widgets/annual_summary_view.dart';
import '../widgets/balance_section.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/transaction_item.dart';
import '../widgets/selectors/date_selector.dart';
import 'add_transaction_screen.dart';

// Repos
import '../repositories/transactions_repository.dart';
import '../repositories/accounts_repository.dart';
import '../repositories/categories_repository.dart';

class AccountDetailScreen extends StatefulWidget {
  final int accountId;
  final String accountName;
  final String accountCurrency;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;

  const AccountDetailScreen({
    Key? key,
    required this.accountId,
    required this.accountName,
    required this.accountCurrency,
    required this.accounts,
    required this.categories,
  }) : super(key: key);

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final _txRepo = TransactionsRepository();
  final _accRepo = AccountsRepository();
  final _catRepo = CategoriesRepository();

  List<Map<String, dynamic>> transactions = [];
  double income = 0.0;
  double expenses = 0.0;
  String mainCurrency = 'USD';
  String selectedFilter = 'monthly';
  String firstWeekday = 'monday';

  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args.containsKey('date')) {
        selectedDate = args['date'];
      }
      if (args.containsKey('filter')) {
        selectedFilter = args['filter'];
      }
    }
    _loadTransactions();
  }

  Future<String> _getFirstWeekday() async => (await SettingsHelper().getFirstWeekday());

  DateTime _startOfWeek(DateTime d, String firstWeekday) {
    final startW = (firstWeekday == 'sunday') ? DateTime.sunday : DateTime.monday;
    final back = (d.weekday - startW + 7) % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: back));
  }

  /// Devuelve (start, endExclusive) según filtro actual.
  Future<(String fromIso, String toIso)> _currentRangeIso() async {
    final firstW = await _getFirstWeekday();

    late DateTime start;
    late DateTime end;

    switch (selectedFilter.toLowerCase()) {
      case 'weekly':
      case 'semanal':
        start = _startOfWeek(selectedDate, firstW);
        end = start.add(const Duration(days: 7));
        break;
      case 'monthly':
      case 'calendar':
      case 'calendario':
        start = DateTime(selectedDate.year, selectedDate.month, 1);
        end = DateTime(selectedDate.year, selectedDate.month + 1, 1);
        break;
      case 'annual':
      case 'anual':
        start = DateTime(selectedDate.year, 1, 1);
        end = DateTime(selectedDate.year + 1, 1, 1);
        break;
      default:
        start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        end = start.add(const Duration(days: 1));
        break;
    }

    // ISO yyyy-MM-dd
    String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    return (iso(start), iso(end.subtract(const Duration(days: 0)))); // usamos <= endIso en repo
  }

  Future<void> _loadData() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'USD';
    firstWeekday = await SettingsHelper().getFirstWeekday();

    // Cargamos cuentas/categorías como Maps para no romper los widgets existentes
    final accModels = await _accRepo.getAll();
    accounts = accModels.map((a) => a.toMap()).toList();

    final catModels = await _catRepo.getAll();
    categories = catModels.map((c) => c.toMap()).toList();

    await _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final range = await _currentRangeIso();
    final fromIso = range.$1;
    final toIso = range.$2;

    // Trae transacciones de la cuenta en el rango
    final txModels = await _txRepo.byAccount(
      widget.accountId,
      fromIso: fromIso,
      toIso: toIso,
      orderBy: 'date DESC, id DESC',
    );

    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    // Adaptamos a Map para reusar TransactionItem existente
    final adjusted = <Map<String, dynamic>>[];

    for (final t in txModels) {
      final txMap = t.toMap();
      final amount = t.amount;
      final converted = await ExchangeRateService.localConvert(amount, t.currency, mainCurrency);
      double convertedAmount = converted;

      if (t.type == 'transfer') {
        if (t.accountId == widget.accountId) {
          totalExpenses += converted;
          convertedAmount = -converted;
        } else if (t.linkedAccountId == widget.accountId) {
          totalIncome += converted;
        }
      } else if (t.type == 'income') {
        totalIncome += converted;
      } else if (t.type == 'expense') {
        totalExpenses += converted;
        convertedAmount = -converted;
      }

      adjusted.add({
        ...txMap,
        'convertedAmount': convertedAmount,
      });
    }

    if (!mounted) return;
    setState(() {
      transactions = adjusted;
      income = totalIncome;
      expenses = totalExpenses;
    });
  }

  Future<String> _getBalanceText(List<Map<String, dynamic>> list) async {
    double inSum = 0;
    double outSum = 0;

    for (final t in list) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final currency = t['currency'] as String? ?? mainCurrency;
      final converted = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

      if (t['type'] == 'income') {
        inSum += converted;
      } else if (t['type'] == 'expense') {
        outSum += converted;
      } else if (t['type'] == 'transfer') {
        if (t['account_id'] == widget.accountId) {
          outSum += converted;
        } else if (t['linked_account_id'] == widget.accountId) {
          inSum += converted;
        }
      }
    }

    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '$mainCurrency ');
    return formatter.format(inSum - outSum);
  }

  Color _getBalanceColor(List<Map<String, dynamic>> list) {
    double inSum = 0;
    double outSum = 0;

    for (final t in list) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      if (t['type'] == 'income') {
        inSum += amount;
      } else if (t['type'] == 'expense') {
        outSum += amount;
      } else if (t['type'] == 'transfer') {
        // cuenta que envía = gasto; que recibe = ingreso
        if (t['account_id'] == widget.accountId) {
          outSum += amount;
        } else if (t['linked_account_id'] == widget.accountId) {
          inSum += amount;
        }
      }
    }

    return (inSum - outSum) >= 0 ? AppColors.ingresoColor : AppColors.gastoColor;
  }

  Widget _buildTransactionList() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final t in transactions) {
      final dateKey = (t['date'] ?? '').toString().split(' ').first;
      grouped.putIfAbsent(dateKey, () => []).add(t);
    }

    if (transactions.isEmpty) {
      return const Center(child: Text('No hay transacciones.'));
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header fecha con balance del día
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(
                      accounts: accounts,
                      categories: categories,
                    ),
                    settings: RouteSettings(arguments: {
                      'date': DateTime.parse(entry.key),
                      'account_id': widget.accountId,
                      'account_currency': widget.accountCurrency,
                    }),
                  ),
                ).then((_) => _loadTransactions());
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('d MMM yyyy').format(DateTime.parse(entry.key)),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                      ),
                    ),
                    FutureBuilder<String>(
                      future: _getBalanceText(entry.value),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? '',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: snapshot.hasData ? _getBalanceColor(entry.value) : Colors.grey,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Items
            ...entry.value.map((tx) {
              return TransactionItem(
                transaction: tx,
                accounts: accounts,
                categories: categories,
                onTransactionUpdated: _loadTransactions,
                currentAccountId: widget.accountId,
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = income - expenses;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom + 80;

    late final Widget contentView;
    if (selectedFilter.toLowerCase() == 'calendario' || selectedFilter.toLowerCase() == 'calendar') {
      contentView = CalendarMonthView(
        selectedDate: selectedDate,
        accounts: widget.accounts,
        categories: widget.categories,
        transactions: transactions,
        onFilterChange: (date, filter) {
          setState(() {
            selectedDate = date;
            selectedFilter = filter;
          });
          _loadTransactions();
        },
      );
    } else if (selectedFilter.toLowerCase() == 'anual' || selectedFilter.toLowerCase() == 'annual') {
      contentView = Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: AnnualSummaryView(
          selectedDate: selectedDate,
          accounts: widget.accounts,
          categories: widget.categories,
          transactions: transactions,
          accountId: widget.accountId,
          accountCurrency: widget.accountCurrency,
          onFilterChange: (date, filter) {
            setState(() {
              selectedDate = date;
              selectedFilter = filter;
            });
            _loadTransactions();
          },
        ),
      );
    } else {
      contentView = Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _buildTransactionList(),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.accountName)),
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
              firsWeekday: firstWeekday,
            ),
            const SizedBox(height: 10),
            BalanceSection(
              totalIncome: income,
              totalExpenses: expenses,
              totalBalance: totalBalance,
              title: 'Resumen de Cuenta',
              mainCurrency: mainCurrency,
            ),
            const SizedBox(height: 10),
            Expanded(child: contentView),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionScreen(
                  accounts: accounts,
                  categories: categories,
                ),
                settings: RouteSettings(arguments: {
                  'account_id': widget.accountId,
                  'account_currency': widget.accountCurrency,
                }),
              ),
            ).then((_) => _loadTransactions());
          },
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
