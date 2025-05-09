import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/database_helper.dart';
import '../utils/exchange_rate_service.dart';
import '../utils/settings_helper.dart';
import '../widgets/annual_summary_view.dart';
import '../widgets/balance_section.dart';
import '../widgets/calendar_month_view.dart';
import '../widgets/transaction_item.dart';
import '../widgets/date_selector.dart';
import 'add_transaction_screen.dart';

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
  List<Map<String, dynamic>> transactions = [];
  double income = 0.0;
  double expenses = 0.0;
  String mainCurrency = 'USD';
  String selectedFilter = 'monthly';
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


  Future<void> _loadData() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'USD';
    final db = DatabaseHelper();
    accounts = await db.getAccounts();
    categories = await db.getCategories();
    await _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final db = DatabaseHelper();
    final result = await db.getTransactionsByAccount(widget.accountId);

    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    final filtered = result.where((tx) {
      DateTime date = DateTime.parse(tx['date']);
      DateTime start;
      DateTime end;

      switch (selectedFilter) {
        case 'weekly':
          start = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
          end = start.add(const Duration(days: 6));
          break;
        case 'monthly':
        case 'calendar':
          start = DateTime(selectedDate.year, selectedDate.month, 1);
          end = DateTime(selectedDate.year, selectedDate.month + 1, 1);
          break;
        case 'annual':
          start = DateTime(selectedDate.year, 1, 1);
          end = DateTime(selectedDate.year + 1, 1, 1);
          break;
        default:
          return true;
      }

      return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          date.isBefore(end);
    }).toList();


    List<Map<String, dynamic>> adjusted = [];

    for (var tx in filtered) {
      double amount = (tx['amount'] as num).toDouble();
      double convertedAmount = await ExchangeRateService.localConvert(
        amount,
        tx['currency'],
        mainCurrency,
      );

      // Lógica especial para transferencias
      if (tx['type'] == 'transfer') {
        if (tx['account_id'] == widget.accountId) {
          totalExpenses += convertedAmount;
          convertedAmount = -convertedAmount;
        } else if (tx['linked_account_id'] == widget.accountId) {
          totalIncome += convertedAmount;
        }
      } else if (tx['type'] == 'income') {
        totalIncome += convertedAmount;
      } else if (tx['type'] == 'expense') {
        totalExpenses += convertedAmount;
        convertedAmount = -convertedAmount;
      }

      adjusted.add({...tx, 'convertedAmount': convertedAmount});
    }

    setState(() {
      transactions = adjusted;
      income = totalIncome;
      expenses = totalExpenses;
    });
  }

  Future<String> _getBalanceText(List<Map<String, dynamic>> transactions) async {
    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      double amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      String currency = t['currency'] ?? mainCurrency;
      double converted = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

      if (t['type'] == 'income') {
        income += converted;
      } else if (t['type'] == 'expense') {
        expense += converted;
      } else if (t['type'] == 'transfer') {
        // Si es cuenta que envió dinero, es gasto
        if (t['account_id'] == widget.accountId) {
          expense += converted;
        }
        // Si es cuenta que recibió, es ingreso
        else if (t['linked_account_id'] == widget.accountId) {
          income += converted;
        }
      }
    }

    double balance = income - expense;
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '$mainCurrency ');
    return formatter.format(balance);
  }


  Widget _buildTransactionList() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var t in transactions) {
      final dateKey = (t['date'] ?? '').split(' ')[0];
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(t);
    }

    if (transactions.isEmpty) {
      return const Center(child: Text('No hay transacciones.'));
    }

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ...entry.value.map((tx) {
              return TransactionItem(
                transaction: tx,
                accounts: accounts,
                categories: categories,
                onTransactionUpdated: _loadTransactions,
                currentAccountId: widget.accountId, // NUEVO
              );
            }).toList(),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalBalance = income - expenses;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom + 80;

    Widget contentView;

    if (selectedFilter.toLowerCase() == "calendario" || selectedFilter.toLowerCase() == "calendar") {
      contentView = CalendarMonthView(
        selectedDate: selectedDate,
        accounts: widget.accounts,
        categories: widget.categories,
        transactions: transactions,
        accountId: widget.accountId,
        accountName: widget.accountName,
      );
    } else if (selectedFilter.toLowerCase() == "anual" || selectedFilter.toLowerCase() == "annual") {
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
        Navigator.pop(context, true); // Devuelve true al cerrar
        return false; // Previene pop automático
      },
      child:Scaffold(
        appBar: AppBar(
          title: Text(widget.accountName),
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
            const SizedBox(height: 10),
            BalanceSection(
              totalIncome: income,
              totalExpenses: expenses,
              totalBalance: totalBalance,
              title: 'Resumen de Cuenta',
              mainCurrency: mainCurrency,
            ),
            const SizedBox(height: 10),
            Expanded(child: contentView,),
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
      )
    );
  }

  Color _getBalanceColor(List<Map<String, dynamic>> transactions) {
    double income = 0;
    double expense = 0;

    for (final t in transactions) {
      double amount = (t['amount'] as num?)?.toDouble() ?? 0.0;

      if (t['type'] == 'income') {
        income += amount;
      } else if (t['type'] == 'expense') {
        expense += amount;
      } else if (t['type'] == 'transfer') {
        if (widget.accountId != null) {
          if (t['account_id'] == widget.accountId) {
            expense += amount;
          } else if (t['linked_account_id'] == widget.accountId) {
            income += amount;
          }
        }
      }
    }

    return (income - expense) >= 0 ? AppColors.ingresoColor : AppColors.gastoColor;
  }

}
