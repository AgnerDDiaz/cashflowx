import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../screen/main_screen.dart';

class AnnualSummaryView extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;

  const AnnualSummaryView({
    Key? key,
    required this.selectedDate,
    required this.accounts,
    required this.categories,
    required this.transactions,
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

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    final allTransactions = await db.getTransactions();

    Map<int, Map<String, double>> monthTotals = {};
    Map<int, List<Map<String, dynamic>>> monthWeeks = {};

    for (var t in allTransactions) {
      final dateStr = t['date'].split(' ')[0];
      final date = DateTime.parse(dateStr);

      if (date.year != widget.selectedDate.year) continue;
      final month = date.month;

      monthTotals.putIfAbsent(month, () => {'income': 0, 'expense': 0, 'balance': 0});

      final amount = t['amount'] ?? 0.0;
      if (t['type'] == 'income') {
        monthTotals[month]!['income'] = monthTotals[month]!['income']! + amount;
        monthTotals[month]!['balance'] = monthTotals[month]!['balance']! + amount;
      } else if (t['type'] == 'expense') {
        monthTotals[month]!['expense'] = monthTotals[month]!['expense']! + amount;
        monthTotals[month]!['balance'] = monthTotals[month]!['balance']! - amount;
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
          if (date.isAfter(endOfWeek) || date.isBefore(startOfWeek)) continue;

          final amount = t['amount'] ?? 0.0;
          if (t['type'] == 'income') income += amount;
          if (t['type'] == 'expense') expense += amount;
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
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(monthLabel,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text("+ \$${summary['income']!.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 10, color: Colors.green)),
                          const SizedBox(width: 6),
                          Text("- \$${summary['expense']!.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 10, color: Colors.red)),
                        ],
                      ),
                      Text("\$${summary['balance']!.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              children: weeklySummary[month]?.map((week) {
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MainScreen(
                              accounts: widget.accounts,
                              categories: widget.categories,
                              transactions: widget.transactions,
                            ),
                            settings: RouteSettings(arguments: {
                              'filter': 'Semanal',
                              'date': week['start'],
                            }),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(week['range'],
                                style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Text("+ \$${week['income'].toStringAsFixed(2)}",
                                        style: const TextStyle(fontSize: 10, color: Colors.green)),
                                    const SizedBox(width: 6),
                                    Text("- \$${week['expense'].toStringAsFixed(2)}",
                                        style: const TextStyle(fontSize: 10, color: Colors.red)),
                                  ],
                                ),
                                Text("\$${week['balance'].toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
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
