// lib/services/scheduled_transactions_processor.dart

import 'dart:async';
import 'package:intl/intl.dart';
import '../repositories/scheduled_transactions_repository.dart';
import '../repositories/transactions_repository.dart';
import '../services/transaction_service.dart';
import '../models/scheduled_transaction.dart';

class ScheduledTransactionsProcessor {
  static bool _running = false; // Evita ejecuciones en paralelo
  final _schedRepo = ScheduledTransactionsRepository();
  final _txRepo = TransactionsRepository();
  final _txService = TransactionService();
  final _fmt = DateFormat('yyyy-MM-dd');

  /// Procesa todas las transacciones recurrentes que debían ejecutarse
  /// hasta el día actual (inclusive).
  Future<void> runDue({DateTime? now}) async {
    if (_running) return; // evita concurrencia
    _running = true;
    try {
      final today = _floorDate(now ?? DateTime.now().toUtc());

      // Buscar todas las recurrentes activas y vencidas
      final dueList = await _schedRepo.allDue(_fmt.format(today));

      for (final s in dueList) {
        await _processScheduledTransaction(s, today);
      }
    } catch (e) {
      print('❌ Error general al ejecutar processor de recurrentes: $e');
    } finally {
      _running = false;
    }
  }

  /// Procesa una transacción recurrente individual
  Future<void> _processScheduledTransaction(
      ScheduledTransaction s, DateTime todayUtc) async {
    try {
      var nextRun = DateTime.parse(s.nextRun);
      final endDate =
      (s.endDate != null && s.endDate!.isNotEmpty) ? DateTime.parse(s.endDate!) : null;

      // Ejecutar todas las fechas faltantes hasta hoy
      while (!nextRun.isAfter(todayUtc)) {
        if (endDate != null && nextRun.isAfter(endDate)) break;

        final dateIso = _fmt.format(nextRun);

        // Verificar si ya existe (anti-duplicado)
        final exists = await _txRepo.existsScheduledOnDate(s.id!, dateIso);
        if (!exists) {
          await _insertRealTransaction(s, dateIso);
        }

        // Avanzar según frecuencia
        nextRun = _advanceNextRun(nextRun, s.frequency);
      }

      // Actualizar el next_run
      await _schedRepo.update(
        s.copyWith(nextRun: _fmt.format(nextRun), failedCount: 0, lastError: null),
      );
    } catch (e) {
      await _schedRepo.update(
        s.copyWith(failedCount: (s.failedCount) + 1, lastError: e.toString()),
      );
    }
  }

  /// Crea la transacción real en la tabla principal
  Future<void> _insertRealTransaction(
      ScheduledTransaction s, String dateIso) async {
    if (s.type == 'income') {
      await _txService.addIncome(
        accountId: s.accountId,
        amount: s.amount,
        currency: s.currency,
        categoryId: s.categoryId,
        dateIso: dateIso,
        note: s.note,
        scheduledId: s.id,
      );
    } else if (s.type == 'expense') {
      await _txService.addExpense(
        accountId: s.accountId,
        amount: s.amount,
        currency: s.currency,
        categoryId: s.categoryId,
        dateIso: dateIso,
        note: s.note,
        scheduledId: s.id,
      );
    } else if (s.type == 'transfer' && s.linkedAccountId != null) {
      await _txService.addTransfer(
        fromAccountId: s.accountId,
        toAccountId: s.linkedAccountId!,
        amount: s.amount,
        currency: s.currency,
        dateIso: dateIso,
        note: s.note,
        scheduledId: s.id,
      );
    }
  }

  /// Calcula la siguiente fecha según frecuencia (maneja fin de mes)
  DateTime _advanceNextRun(DateTime d, String freq) {
    DateTime addMonths(int n) {
      final year = d.year;
      final month = d.month + n;
      final lastDay = DateTime(year, month + 1, 0).day;
      final day = d.day > lastDay ? lastDay : d.day;
      return DateTime(year, month, day);
    }

    switch (freq.toLowerCase()) {
      case 'weekly':
        return d.add(const Duration(days: 7));
      case 'biweekly':
        return d.add(const Duration(days: 14));
      case 'monthly':
        return addMonths(1);
      case 'quarterly':
        return addMonths(3);
      case 'semiannual':
        return addMonths(6);
      case 'annual':
        return DateTime(d.year + 1, d.month, d.day);
      default:
        return addMonths(1);
    }
  }

  DateTime _floorDate(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  // ============================================================
  // NUEVO: utilidades públicas sin romper la API existente
  // ============================================================

  /// Materializa inmediatamente la regla si su `next_run` es hoy o está en el pasado,
  /// y luego avanza `next_run` al siguiente ciclo (idempotente).
  /// Úsalo justo después de CREAR o REINICIAR una regla cuya fecha inicio = hoy.
  Future<void> materializeIfDueNow(int scheduledId, {DateTime? now}) async {
    final today = _floorDate(now ?? DateTime.now().toUtc());
    final s = await _schedRepo.getById(scheduledId);
    if (s == null) return;
    if (s.isActive == 0) return;

    // si nextRun <= hoy → crear movimiento de hoy si aún no existe
    var nextRun = DateTime.parse(s.nextRun);
    if (!nextRun.isAfter(today)) {
      final dateIso = _fmt.format(today);

      final exists = await _txRepo.existsScheduledOnDate(s.id!, dateIso);
      if (!exists) {
        await _insertRealTransaction(s, dateIso);
      }

      // avanzar próximo cobro desde "hoy"
      nextRun = _advanceNextRun(today, s.frequency);
      await _schedRepo.update(
        s.copyWith(nextRun: _fmt.format(nextRun), failedCount: 0, lastError: null),
      );
    }
  }

  /// Helper público por si quieres reusar el cálculo fuera.
  DateTime advanceNextRunPublic(DateTime d, String freq) => _advanceNextRun(d, freq);
}
