import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../screen/main_screen.dart';
import '../utils/app_colors.dart';
import '../utils/exchange_rate_service.dart';
import '../utils/settings_helper.dart';


class AnnualSummaryView extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;
  final void Function(DateTime date, String filter)? onFilterChange;
  final int? accountId;
  final String? accountCurrency;


  const AnnualSummaryView({
    Key? key,
    required this.selectedDate,
    required this.accounts,
    required this.categories,
    required this.transactions,
    this.onFilterChange,
    this.accountId,
    this.accountCurrency,
  }) : super(key: key);

  @override
  State<AnnualSummaryView> createState() => _AnnualSummaryViewState();
}

class _AnnualSummaryViewState extends State<AnnualSummaryView> {
  Map<int, Map<String, double>> monthlySummary = {};
  Map<int, List<Map<String, dynamic>>> weeklySummary = {};
  int? _expandedMonth;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AnnualSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    final mainCurrency = await SettingsHelper().getMainCurrency();
    final allTransactions = widget.accountId != null
        ? await db.getTransactionsByAccount(widget.accountId!)
        : await db.getTransactions();

    Map<int, Map<String, double>> monthTotals = {};
    Map<int, List<Map<String, dynamic>>> monthWeeks = {};

    for (var t in allTransactions) {
      final dateStr = t['date'].split(' ')[0];
      final date = DateTime.parse(dateStr);

      if (date.year != widget.selectedDate.year) continue;

      final month = date.month;
      final amount = t['amount'] ?? 0.0;
      final currency = t['currency'] ?? 'USD';
      final converted = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

      monthTotals.putIfAbsent(month, () => {'income': 0, 'expense': 0, 'balance': 0});

      if (t['type'] == 'income') {
        monthTotals[month]!['income'] = monthTotals[month]!['income']! + converted;
        monthTotals[month]!['balance'] = monthTotals[month]!['balance']! + converted;
      } else if (t['type'] == 'expense') {
        monthTotals[month]!['expense'] = monthTotals[month]!['expense']! + converted;
        monthTotals[month]!['balance'] = monthTotals[month]!['balance']! - converted;
      } else if (t['type'] == 'transfer') {
        if (widget.accountId != null) {
          if (t['account_id'] == widget.accountId) {
            monthTotals[month]!['expense'] = monthTotals[month]!['expense']! + converted;
            monthTotals[month]!['balance'] = monthTotals[month]!['balance']! - converted;
          } else if (t['linked_account_id'] == widget.accountId) {
            monthTotals[month]!['income'] = monthTotals[month]!['income']! + converted;
            monthTotals[month]!['balance'] = monthTotals[month]!['balance']! + converted;
          }
        }
      }
    }

    for (int month = 1; month <= 12; month++) {
      DateTime firstDayOfMonth = DateTime(widget.selectedDate.year, month, 1);
      DateTime lastDayOfMonth = DateTime(widget.selectedDate.year, month + 1, 0);
      DateTime startOfWeek = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));
      DateTime endOfCalendar = lastDayOfMonth.add(Duration(days: 7 - lastDayOfMonth.weekday));

      List<Map<String, dynamic>> weeks = [];

      while (startOfWeek.isBefore(endOfCalendar)) {
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        double income = 0;
        double expense = 0;

        for (var t in allTransactions) {
          final dateStr = t['date'].split(' ')[0];
          final date = DateTime.parse(dateStr);

          if (date.isBefore(startOfWeek) || date.isAfter(endOfWeek)) continue;

          final amount = t['amount'] ?? 0.0;
          final currency = t['currency'] ?? 'USD';
          final converted = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

          if (t['type'] == 'income') {
            income += converted;
          } else if (t['type'] == 'expense') {
            expense += converted;
          } else if (t['type'] == 'transfer') {
            if (widget.accountId != null) {
              if (t['account_id'] == widget.accountId) {
                expense += converted;
              } else if (t['linked_account_id'] == widget.accountId) {
                income += converted;
              }
            }
          }
        }

        if (startOfWeek.isAfter(lastDayOfMonth)) break;

        weeks.add({
          'range': "${startOfWeek.day}/${startOfWeek.month} ~ ${endOfWeek.day}/${endOfWeek.month}",
          'start': startOfWeek,
          'income': income,
          'expense': expense,
          'balance': income - expense,
        });

        startOfWeek = endOfWeek.add(const Duration(days: 1));
      }

      monthWeeks[month] = weeks;
    }

    setState(() {
      monthlySummary = monthTotals;
      weeklySummary = monthWeeks;
    });
  }


  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final summary = monthlySummary[month] ?? {'income': 0, 'expense': 0, 'balance': 0};
        final start = DateTime(widget.selectedDate.year, month, 1);
        final end = DateTime(widget.selectedDate.year, month + 1, 0);
        final monthLabel = DateFormat.MMMM().format(start);

        return Column(
          children: [
            ExpansionTile(
              trailing: const SizedBox.shrink(),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedMonth = expanded ? month : null;
                });
              },
              initiallyExpanded: _expandedMonth == month,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${start.day}/${start.month} ~ ${end.day}/${end.month}",
                          style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                      Text(monthLabel,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color,)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text("+ \$${summary['income']!.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 10, color: AppColors.ingresoColor)),

                          const SizedBox(width: 6),
                          Text("- \$${summary['expense']!.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 10, color: AppColors.gastoColor)),

                        ],
                      ),
                      Text("\$${summary['balance']!.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),

                    ],
                  ),
                ],
              ),
              children: weeklySummary[month]?.map((week) {
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.onFilterChange != null) {
                          widget.onFilterChange!(week['start'], 'weekly');
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(week['range'],
                                style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Text("+ \$${week['income'].toStringAsFixed(2)}",
                                        style: TextStyle(fontSize: 10, color: AppColors.ingresoColor)),
                                    const SizedBox(width: 6),
                                    Text("- \$${week['expense'].toStringAsFixed(2)}",
                                        style: TextStyle(fontSize: 10, color: AppColors.gastoColor)),
                                      ],
                                ),
                                Text("\$${week['balance'].toStringAsFixed(2)}",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(thickness: 1, height: 1), // ✅ Divider entre semanas
                  ],
                );
              }).toList() ?? [],
            ),
            if (month != 12) const Divider(thickness: 1, height: 1), // ✅ Divider entre meses
          ],
        );
      },
    );
  }
}
