import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';

class CalendarMonthView extends StatefulWidget {
  final DateTime selectedDate;

  const CalendarMonthView({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  Map<String, Map<String, double>> dailySummary = {}; // fecha -> { income, expense, balance }

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    final db = DatabaseHelper();
    final allTransactions = await db.getTransactions();

    final start = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    final end = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0);

    Map<String, Map<String, double>> summary = {};

    for (var t in allTransactions) {
      final dateStr = t['date'].split(' ')[0];
      final date = DateTime.parse(dateStr);
      if (date.isBefore(start) || date.isAfter(end)) continue;

      summary.putIfAbsent(dateStr, () => {'income': 0, 'expense': 0, 'balance': 0});

      final amount = t['amount'] ?? 0.0;
      if (t['type'] == 'income') {
        summary[dateStr]!['income'] = summary[dateStr]!['income']! + amount;
        summary[dateStr]!['balance'] = summary[dateStr]!['balance']! + amount;
      } else if (t['type'] == 'expense') {
        summary[dateStr]!['expense'] = summary[dateStr]!['expense']! + amount;
        summary[dateStr]!['balance'] = summary[dateStr]!['balance']! - amount;
      }
    }

    setState(() => dailySummary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    final totalDays = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // lunes = 1 => 1

    List<Widget> rows = [];
    int day = 1;
    for (int week = 0; week < 6; week++) {
      List<Widget> days = [];
      for (int i = 0; i < 7; i++) {
        if (week == 0 && i < firstWeekday) {
          days.add(_emptyCell());
        } else if (day > totalDays) {
          days.add(_emptyCell());
        } else {
          days.add(_buildDayCell(day));
          day++;
        }
      }
      rows.add(Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: days));
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          DateFormat('MMMM yyyy').format(widget.selectedDate),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
              .map((d) => Expanded(
            child: Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.bold))),
          ))
              .toList(),
        ),
        const SizedBox(height: 4),
        ...rows,
      ],
    );
  }

  Widget _buildDayCell(int day) {
    final date = DateTime(widget.selectedDate.year, widget.selectedDate.month, day);
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final data = dailySummary[dateStr] ?? {'income': 0.0, 'expense': 0.0, 'balance': 0.0};

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text("$day", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("${data['income']!.toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.blue, fontSize: 10)),
            Text("${data['expense']!.toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.red, fontSize: 10)),
            Text("${data['balance']!.toStringAsFixed(0)}",
                style: TextStyle(
                  color: data['balance']! >= 0 ? Colors.green : Colors.red,
                  fontSize: 10,
                )),
          ],
        ),
      ),
    );
  }

  Widget _emptyCell() {
    return Expanded(child: Container(margin: const EdgeInsets.all(2)));
  }
}
