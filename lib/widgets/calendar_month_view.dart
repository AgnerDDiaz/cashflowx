import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_colors.dart';
import '../services/exchange_rate_service.dart';
import '../utils/settings_helper.dart';

/// Notifica al padre un cambio de filtro/fecha
typedef FilterChange = void Function(DateTime date, String filter);

class CalendarMonthView extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;
  final FilterChange onFilterChange;

  const CalendarMonthView({
    super.key,
    required this.selectedDate,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.onFilterChange,
  });

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  // Preferencias
  String _firstWeekday = 'monday'; // 'monday' | 'sunday'
  String _mainCurrency = 'DOP';

  // 42 celdas visibles (6 semanas x 7 días)
  List<DateTime> _visibleDays = const [];

  // Resumen por día (yyyy-MM-dd)
  final Map<String, _DaySummary> _dailySummary = {};

  @override
  void initState() {
    super.initState();
    _loadPrefsAndBuild();
  }

  @override
  void didUpdateWidget(covariant CalendarMonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month ||
        oldWidget.transactions != widget.transactions) {
      _rebuildVisibleDays();
      _rebuildSummary();
    }
  }

  Future<void> _loadPrefsAndBuild() async {
    final first = await SettingsHelper().getFirstWeekday();
    final currency = await SettingsHelper().getMainCurrency();
    setState(() {
      _firstWeekday = (first == 'sunday') ? 'sunday' : 'monday';
      _mainCurrency = currency;
    });
    _rebuildVisibleDays();
    await _rebuildSummary();
  }

  /// Inicio de semana según configuración (domingo o lunes)
  DateTime _startOfWeek(DateTime d) {
    final startWeekday =
    (_firstWeekday == 'sunday') ? DateTime.sunday : DateTime.monday;
    final back = (d.weekday - startWeekday + 7) % 7;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: back));
  }

  void _rebuildVisibleDays() {
    final firstDayOfMonth =
    DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    final lastDayOfMonth =
    DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0);

    final startWeekday =
    (_firstWeekday == 'sunday') ? DateTime.sunday : DateTime.monday;

    // Primer visible = retroceder hasta el inicio de semana
    final back = (firstDayOfMonth.weekday - startWeekday + 7) % 7;
    final firstVisible = firstDayOfMonth.subtract(Duration(days: back));

    // Último visible = avanzar hasta el fin de semana
    int forward;
    if (startWeekday == DateTime.monday) {
      // Semana termina en domingo
      forward = (7 - lastDayOfMonth.weekday) % 7;
    } else {
      // Semana empieza domingo, termina sábado
      forward = (lastDayOfMonth.weekday % 7);
    }
    DateTime lastVisible = lastDayOfMonth.add(Duration(days: forward));

    // Garantizar 42 celdas
    int count = lastVisible.difference(firstVisible).inDays + 1;
    if (count < 42) {
      lastVisible = lastVisible.add(Duration(days: 42 - count));
    }

    final days = List<DateTime>.generate(
      lastVisible.difference(firstVisible).inDays + 1,
          (i) => DateTime(
          firstVisible.year, firstVisible.month, firstVisible.day + i),
    );

    setState(() {
      _visibleDays = days;
    });
  }

  Future<void> _rebuildSummary() async {
    _dailySummary.clear();

    for (final t in widget.transactions) {
      final raw = t['date'] as String?;
      if (raw == null) continue;

      DateTime d;
      try {
        d = DateTime.parse(raw);
      } catch (_) {
        continue;
      }


      final dayKey = DateFormat('yyyy-MM-dd').format(d);
      final type = (t['type'] as String?) ?? '';
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final currency = (t['currency'] as String?) ?? _mainCurrency;

      final converted =
      await ExchangeRateService.localConvert(amount, currency, _mainCurrency);

      _dailySummary.putIfAbsent(dayKey, () => _DaySummary.zero());
      if (type == 'income') {
        _dailySummary[dayKey] =
            _dailySummary[dayKey]!.add(income: converted);
      } else if (type == 'expense') {
        _dailySummary[dayKey] =
            _dailySummary[dayKey]!.add(expense: converted);
      }
      // transfer: se omite del resumen global
    }

    if (mounted) setState(() {});
  }

  List<String> _weekdayLabels(BuildContext context) {
    // Usamos anclas con día conocido para evitar trucos raros:
    // 2024-01-01 fue Lunes; 2023-12-31 fue Domingo.
    final String locale = context.locale.toString();
    final DateTime anchor = (_firstWeekday == 'sunday')
        ? DateTime(2023, 12, 31) // Domingo
        : DateTime(2024, 1, 1);   // Lunes

    return List<String>.generate(
      7,
          (i) => DateFormat.E(locale).format(anchor.add(Duration(days: i))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekdayLabels = _weekdayLabels(context);


    return Column(
      children: [
        _WeekHeader(labels: weekdayLabels),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = constraints.maxWidth / 7;
              final cellHeight = constraints.maxHeight / 6;

              return Padding(
                // margen para FAB/bottom bar y evitar overflow
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 80,
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _visibleDays.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: cellWidth / cellHeight,
                  ),
                  itemBuilder: (_, i) {
                    final date = _visibleDays[i];
                    final isCurrentMonth =
                        date.month == widget.selectedDate.month;
                    return _buildDayCell(
                        context, date, isCurrentMonth, cellWidth, cellHeight);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(
      BuildContext context, DateTime date, bool isCurrentMonth, double w, double h) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final summary = _dailySummary[dateKey] ?? _DaySummary.zero();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Paleta basada en el tema para evitar “blancos”
    final Color baseInMonth = Theme.of(context).cardColor;
    final Color baseOutMonth =
    isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);

    // Días sin movimientos usan un fondo un poco más apagado
    final bool empty = summary.isEmpty;
    final Color bgColor = !isCurrentMonth
        ? baseOutMonth
        : (empty
        ? (isDark ? baseInMonth.withOpacity(0.65) : baseInMonth.withOpacity(0.85))
        : baseInMonth);

    // Color del balance por signo
    final double bal = summary.balance;
    final Color balColor = bal > 0
        ? AppColors.ingresoColor
        : (bal < 0
        ? AppColors.gastoColor
        : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ??
        Colors.grey);

    return InkWell(
      onTap: () {
        // Cambia a vista semanal centrada en esta fecha
        final start = _startOfWeek(date);
        widget.onFilterChange(start, 'weekly');
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentMonth
                ? Colors.transparent
                : (isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06)),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Día
            Text(
              '${date.day}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isCurrentMonth
                    ? Theme.of(context).textTheme.labelLarge?.color
                    : Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.color
                    ?.withOpacity(0.40),
              ),
            ),
            const Spacer(),
            // ===== SOLO BALANCE (sin símbolo), color por signo =====
            if (!summary.isEmpty)
              _LineAmount(
                amount: bal,
                currency: _mainCurrency,
                color: balColor,
                fontSize: 10, // baja a 9 si lo quieres aún más compacto
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  final List<String> labels;
  const _WeekHeader({required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: labels
          .map(
            (l) => Expanded(
          child: Center(
            child: Text(
              l.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withOpacity(0.7),
              ),
            ),
          ),
        ),
      )
          .toList(),
    );
  }
}

class _LineAmount extends StatelessWidget {
  final double amount;
  final String currency; // se mantiene por compatibilidad
  final Color? color;
  final double fontSize;

  const _LineAmount({
    required this.amount,
    required this.currency,
    this.color,
    this.fontSize = 10, // más pequeño por defecto
  });

  @override
  Widget build(BuildContext context) {
    if (amount == 0) return const SizedBox.shrink();

    final f = NumberFormat.decimalPattern();
    f.minimumFractionDigits = 0;
    f.maximumFractionDigits = 0;

    return Padding(
      padding: const EdgeInsets.only(top: 1.5),
      child: Text(
        f.format(amount), // solo número, sin símbolo
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: 1.0,
          color: color,
        ),
      ),
    );
  }
}

class _DaySummary {
  final double income;
  final double expense;

  const _DaySummary(this.income, this.expense);

  factory _DaySummary.zero() => const _DaySummary(0, 0);

  bool get isEmpty => income == 0 && expense == 0;
  double get balance => income - expense;

  _DaySummary add({double income = 0, double expense = 0}) =>
      _DaySummary(this.income + income, this.expense + expense);
}
