import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../repositories/transactions_repository.dart';
import '../repositories/credit_cards_repository.dart';
import '../models/credit_card_meta.dart';
import '../services/exchange_rate_service.dart';

class CreditCardCycleTotals {
  final double statementDue;   // neto a pagar del ciclo cerrado
  final double postStatement;  // neto acumulado post-corte (próximo ciclo)
  final int? statementDay;     // día de corte (1–28)
  final int? dueDay;           // día de pago (1–28)

  const CreditCardCycleTotals({
    required this.statementDue,
    required this.postStatement,
    required this.statementDay,
    required this.dueDay,
  });
}

class CreditCardCalculator {
  final TransactionsRepository _txRepo = TransactionsRepository();
  final CreditCardsRepository _cardsRepo = CreditCardsRepository();

  /// Calcula los totales de tarjeta a una fecha [asOf] (default: hoy).
  /// - Usa statement_day/due_day de `credit_cards_meta`.
  /// - Clasifica transacciones en "Este ciclo" vs "Próximo ciclo".
  /// - Convierte cada transacción a la moneda de la cuenta.
  Future<CreditCardCycleTotals> compute(Account account, {DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();

    // 1) Meta de la tarjeta (corte/pago/limite)
    final meta = await _cardsRepo.getMeta(account.id!);
    final statementDay = meta?.statementDay ?? 1;
    final dueDay = meta?.dueDay;

    // Clamp por seguridad (1..28)
    final cutoff = statementDay.clamp(1, 28);

    // 2) Ventanas de corte
    final prevCut = _cutDateOnOrBefore(now, cutoff);           // último corte ≤ asOf
    final prevPrevCut = _cutDateOnOrBefore(_prevMonth(now), cutoff);
    final nextCut = _cutDateAfter(prevCut, cutoff);

    // 3) Traer transacciones de ventana amplia (un mes antes al próximo corte)
    final fromIso = _iso(prevPrevCut.add(const Duration(days: 1))); // (prevPrevCut, ...]
    final toIso = _iso(nextCut);                                    // ... <= nextCut
    final txs = await _txRepo.byAccount(account.id!,
        fromIso: fromIso, toIso: toIso, orderBy: 'date ASC, id ASC');

    // 4) Sumar por ventana, con conversión a la moneda de la cuenta
    double sumStatement = 0.0;
    double sumPost = 0.0;

    for (final t in txs) {
      // Normaliza a moneda de la cuenta
      final convAmount = await ExchangeRateService.localConvert(
        t.amount.abs(),
        t.currency,
        account.currency,
      );

      // Ventana a la que pertenece
      final d = DateTime.parse(t.date);
      final inStatement = d.isAfter(prevPrevCut) && !d.isAfter(prevCut); // (prevPrevCut, prevCut]
      final inPost = d.isAfter(prevCut) && !d.isAfter(nextCut);          // (prevCut, nextCut]

      // Signo según tipo
      double signed = convAmount;
      if (t.type == AppTransaction.typeIncome) {
        // Abono/pago → resta del adeudo
        signed = -convAmount;
      } else if (t.type == AppTransaction.typeExpense) {
        // Consumo → suma al adeudo
        signed = convAmount;
      } else {
        // transfer: la ignoramos en el card view
        continue;
      }

      if (inStatement) {
        sumStatement += signed;
      } else if (inPost) {
        sumPost += signed;
      }
    }

    // 5) No forzamos mínimos en 0: si el usuario abonó más, el neto puede ser 0 o negativo.
    return CreditCardCycleTotals(
      statementDue: _round2(sumStatement),
      postStatement: _round2(sumPost),
      statementDay: cutoff,
      dueDay: dueDay,
    );
  }

  // ===============================
  // Helpers de fechas
  // ===============================

  // Devuelve el corte del mes de [base] (día= cutoff).
  DateTime _cutOfMonth(DateTime base, int cutoff) =>
      DateTime(base.year, base.month, cutoff);

  // Último corte <= fecha
  DateTime _cutDateOnOrBefore(DateTime date, int cutoff) {
    final thisMonthCut = _cutOfMonth(date, cutoff);
    if (!date.isBefore(thisMonthCut)) return thisMonthCut;
    final pm = _prevMonth(date);
    return _cutOfMonth(pm, cutoff);
  }

  // Siguiente corte después de [fromCut]
  DateTime _cutDateAfter(DateTime fromCut, int cutoff) {
    final nm = _nextMonth(fromCut);
    return _cutOfMonth(nm, cutoff);
  }

  DateTime _prevMonth(DateTime d) =>
      DateTime(d.year, d.month - 1, d.day.clamp(1, 28));

  DateTime _nextMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, d.day.clamp(1, 28));

  String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  double _round2(double v) => (v * 100).roundToDouble() / 100.0;
}
