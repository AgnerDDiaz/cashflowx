import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_colors.dart';
import '../services/exchange_rate_service.dart';
import '../utils/settings_helper.dart';
import '../repositories/transactions_repository.dart';

class AnnualSummaryView extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions; // no lo usamos aquí, pero lo mantenemos por compatibilidad
  final void Function(DateTime date, String filter)? onFilterChange;

  /// Si viene, el resumen se calcula solo para esa cuenta.
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
  final _txRepo = TransactionsRepository();

  Map<int, Map<String, double>> monthlySummary = {}; // {month: {income, expense, balance}}
  Map<int, List<Map<String, dynamic>>> weeklySummary = {}; // {month: [ {range, start, income, expense, balance} ]}
  int? _expandedMonth;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AnnualSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.accountId != widget.accountId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final mainCurrency = await SettingsHelper().getMainCurrency() ?? 'USD';

    // 1) Traer transacciones
    final allTx = widget.accountId != null
        ? await _txRepo.byAccount(widget.accountId!) // todo el histórico de esa cuenta
        : await _txRepo.all();                       // todas las cuentas

    // 2) Agregar solo las del año seleccionado
    Map<int, Map<String, double>> monthTotals = {};
    Map<int, List<Map<String, dynamic>>> monthWeeks = {};

    for (final t in allTx) {
      final date = DateTime.parse(t.date); // t.date es 'YYYY-MM-DD'
      if (date.year != widget.selectedDate.year) continue;

      final month = date.month;
      final amount = t.amount;
      final currency = t.currency;
      final converted = await ExchangeRateService.localConvert(amount, currency, mainCurrency);

      monthTotals.putIfAbsent(month, () => {'income': 0, 'expense': 0, 'balance': 0});

      if (t.type == 'income') {
        monthTotals[month]!['income'] = monthTotals[month]!['income']! + converted;
        monthTotals[month]!['balance'] = monthTotals[month]!['balance']! + converted;
      } else if (t.type == 'expense') {
        monthTotals[month]!['expense'] = monthTotals[month]!['expense']! + converted;
        monthTotals[month]!['balance'] = monthTotals[month]!['balance']! - converted;
      } else if (t.type == 'transfer') {
        // Si estamos en vista por cuenta, tratamos transfer como ingreso/egreso según el lado
        if (widget.accountId != null) {
          if (t.accountId == widget.accountId) {
            monthTotals[month]!['expense'] = monthTotals[month]!['expense']! + converted;
            monthTotals[month]!['balance'] = monthTotals[month]!['balance']! - converted;
          } else if (t.linkedAccountId == widget.accountId) {
            monthTotals[month]!['income'] = monthTotals[month]!['income']! + converted;
            monthTotals[month]!['balance'] = monthTotals[month]!['balance']! + converted;
          }
        }
      }
    }

    // 3) Construir semanas visibles por mes (semana calendario Lun-Dom)
    for (int month = 1; month <= 12; month++) {
      final firstDay = DateTime(widget.selectedDate.year, month, 1);
      final lastDay = DateTime(widget.selectedDate.year, month + 1, 0);

      // inicio de semana (lunes) conteniendo el primer día del mes
      DateTime startOfWeek = firstDay.subtract(Duration(days: (firstDay.weekday + 6) % 7));
      // fin de calendario: domingo de la última semana que contenga el último día del mes
      DateTime endOfCalendar = lastDay.add(Duration(days: 7 - ((lastDay.weekday % 7) + 1)));

      final weeks = <Map<String, dynamic>>[];

      while (!startOfWeek.isAfter(endOfCalendar)) {
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        double income = 0.0;
        double expense = 0.0;

        for (final t in allTx) {
          final date = DateTime.parse(t.date);
          if (date.isBefore(startOfWeek) || date.isAfter(endOfWeek)) continue;
          if (date.year != widget.selectedDate.year || date.month != month) continue;

          final converted = await ExchangeRateService.localConvert(t.amount, t.currency, mainCurrency);

          if (t.type == 'income') {
            income += converted;
          } else if (t.type == 'expense') {
            expense += converted;
          } else if (t.type == 'transfer' && widget.accountId != null) {
            if (t.accountId == widget.accountId) {
              expense += converted;
            } else if (t.linkedAccountId == widget.accountId) {
              income += converted;
            }
          }
        }

        // solo agregamos semanas que tocan el mes
        if (!endOfWeek.isBefore(firstDay) && !startOfWeek.isAfter(lastDay)) {
          weeks.add({
            'range': "${startOfWeek.day}/${startOfWeek.month} ~ ${endOfWeek.day}/${endOfWeek.month}",
            'start': startOfWeek,
            'income': income,
            'expense': expense,
            'balance': income - expense,
          });
        }

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
                setState(() => _expandedMonth = expanded ? month : null);
              },
              initiallyExpanded: _expandedMonth == month,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("${start.day}/${start.month} ~ ${end.day}/${end.month}",
                        style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                    Text(monthLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        )),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(children: [
                      Text("+ \$${summary['income']!.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 10, color: AppColors.ingresoColor)),
                      const SizedBox(width: 6),
                      Text("- \$${summary['expense']!.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 10, color: AppColors.gastoColor)),
                    ]),
                    Text("\$${summary['balance']!.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        )),
                  ]),
                ],
              ),
              children: (weeklySummary[month] ?? []).map((week) {
                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.onFilterChange != null) {
                          widget.onFilterChange!(week['start'] as DateTime, 'weekly');
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(week['range'] as String,
                                style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(children: [
                                  Text("+ \$${(week['income'] as double).toStringAsFixed(2)}",
                                      style: TextStyle(fontSize: 10, color: AppColors.ingresoColor)),
                                  const SizedBox(width: 6),
                                  Text("- \$${(week['expense'] as double).toStringAsFixed(2)}",
                                      style: TextStyle(fontSize: 10, color: AppColors.gastoColor)),
                                ]),
                                Text("\$${(week['balance'] as double).toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(thickness: 1, height: 1),
                  ],
                );
              }).toList(),
            ),
            if (month != 12) const Divider(thickness: 1, height: 1),
          ],
        );
      },
    );
  }
}
