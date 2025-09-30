import 'package:flutter/foundation.dart';

/// Monday = 1 ... Sunday = 7 (igual que DateTime.monday/sunday)
enum FirstWeekday { monday, sunday }

class DateRanges {
  static FirstWeekday parseFirstWeekday(String code) {
    return code.toLowerCase() == 'sunday'
        ? FirstWeekday.sunday
        : FirstWeekday.monday; // default
  }

  static int toDartWeekday(FirstWeekday fw) {
    return fw == FirstWeekday.sunday ? DateTime.sunday : DateTime.monday;
  }

  /// Devuelve el inicio de semana (00:00 local) alineado al primer día elegido.
  static DateTime weekStart(DateTime d, FirstWeekday firstWeekday) {
    final wd = d.weekday; // 1..7
    final startWd = toDartWeekday(firstWeekday); // 1 o 7
    // en Dart, % con negativos puede ser negativo, así que normalizamos:
    int delta = (wd - startWd) % 7;
    if (delta < 0) delta += 7;
    final localMidnight = DateTime(d.year, d.month, d.day);
    return localMidnight.subtract(Duration(days: delta));
  }

  /// Rango semanal [start, end) ⇒ fin EXCLUSIVO (evita que el 29 caiga en 22–28).
  static ({DateTime start, DateTime end}) weeklyRange(DateTime anchor, FirstWeekday fw) {
    final start = weekStart(anchor, fw);
    final end = start.add(const Duration(days: 7));
    return (start: start, end: end);
  }
}
