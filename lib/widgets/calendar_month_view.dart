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

  @override
  void didUpdateWidget(CalendarMonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadMonthlyData();
    }
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
      if (date.isBefore(start.subtract(const Duration(days: 7))) || date.isAfter(end.add(const Duration(days: 7)))) continue;

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
    final totalDaysInMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0).day;
    final firstWeekday = (firstDayOfMonth.weekday + 6) % 7; // lunes = 0

    final prevMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month - 1, 1);
    final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;

    List<Widget> rows = [];
    int totalCells = 42; // 6 weeks * 7 days

    for (int i = 0; i < totalCells; i += 7) {
      rows.add(Row(
        children: List.generate(7, (j) => Expanded(child: _buildDayCell(i + j, firstWeekday, totalDaysInMonth, daysInPrevMonth))),
      ));
    }

    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                .map((d) => Expanded(
              child: Center(
                  child: Text(d,
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ))
                .toList(),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDayCell(int index, int firstWeekday, int totalDaysInMonth, int daysInPrevMonth) {
    int dayNum = index - firstWeekday + 1;
    DateTime date;
    bool isCurrentMonth = true;

    if (dayNum < 1) {
      isCurrentMonth = false;
      date = DateTime(widget.selectedDate.year, widget.selectedDate.month - 1, daysInPrevMonth + dayNum);
    } else if (dayNum > totalDaysInMonth) {
      isCurrentMonth = false;
      date = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, dayNum - totalDaysInMonth);
    } else {
      date = DateTime(widget.selectedDate.year, widget.selectedDate.month, dayNum);
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final data = dailySummary[dateStr] ?? {'income': 0.0, 'expense': 0.0, 'balance': 0.0};

    return Container(
      height: MediaQuery.of(context).size.height / 12,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isCurrentMonth ? Colors.grey.shade200 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrentMonth ? Colors.black : Colors.grey.shade600,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${data['income']!.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, color: Colors.green)),
                Text("${data['expense']!.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, color: Colors.red)),
                Text("${data['balance']!.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
