import 'package:flutter/foundation.dart';

import '../repositories/accounts_repository.dart';
import '../repositories/transactions_repository.dart';
import '../services/exchange_rate_service.dart';

import '../models/account.dart';
import '../models/transaction.dart';

class TransactionService {
  final AccountsRepository _accountsRepo = AccountsRepository();
  final TransactionsRepository _txRepo = TransactionsRepository();
  final ExchangeRateService _fx = ExchangeRateService();

  // ========== CREAR ==========

  Future<AppTransaction> addExpense({
    required int accountId,
    required double amount,
    required String currency,
    int? categoryId,
    required String dateIso,
    String? note,
  }) async {
    final tx = AppTransaction(
      accountId: accountId,
      type: AppTransaction.typeExpense,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: dateIso,
      note: note,
    );

    final inserted = await _txRepo.insert(tx);
    await _applyBalanceDelta(accountId, -amount, txCurrency: currency);
    return inserted;
  }

  Future<AppTransaction> addIncome({
    required int accountId,
    required double amount,
    required String currency,
    int? categoryId,
    required String dateIso,
    String? note,
  }) async {
    final tx = AppTransaction(
      accountId: accountId,
      type: AppTransaction.typeIncome,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: dateIso,
      note: note,
    );

    final inserted = await _txRepo.insert(tx);
    await _applyBalanceDelta(accountId, amount, txCurrency: currency);
    return inserted;
  }

  /// Transferencia: una sola fila tipo 'transfer' con linked_account_id.
  /// Efectos de saldo: -amount a origen (+conversion si moneda distinta) y +amount convertido a destino.
  Future<AppTransaction> addTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required String currency, // moneda del monto introducido
    required String dateIso,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      throw ArgumentError('Las cuentas de origen y destino no pueden ser iguales.');
    }

    final tx = AppTransaction(
      accountId: fromAccountId,
      linkedAccountId: toAccountId,
      type: AppTransaction.typeTransfer,
      amount: amount,
      currency: currency,
      categoryId: null,
      date: dateIso,
      note: note,
    );

    final inserted = await _txRepo.insert(tx);

    // Ajustar saldos de ambas cuentas
    // Origen: resta
    await _applyBalanceDelta(fromAccountId, -amount, txCurrency: currency);

    // Destino: suma (conversión si destino usa otra moneda)
    final destAcc = await _accountsRepo.getById(toAccountId);
    final destCurrency = destAcc?.currency ?? currency;
    double credit = amount;
    if (destCurrency != currency) {
      final rate = await _fx.getExchangeRate(currency, destCurrency);
      credit = amount * rate;
    }
    await _applyBalanceDelta(toAccountId, credit, txCurrency: destCurrency);

    return inserted;
  }

  // ========== ACTUALIZAR ==========

  /// Actualiza una transacción revirtiendo primero el efecto de la original y aplicando el de la nueva.
  Future<void> updateTransaction(AppTransaction updated) async {
    if (updated.id == null) {
      throw ArgumentError('La transacción a actualizar debe tener id.');
    }

    final current = await _txRepo.getById(updated.id!);
    if (current == null) {
      throw StateError('Transacción no encontrada (id=${updated.id}).');
    }

    // 1) Revertir efectos de la actual
    await _revertBalanceEffect(current);

    // 2) Guardar cambios
    await _txRepo.update(updated);

    // 3) Aplicar efectos de la nueva versión
    await _applyBalanceEffect(updated);
  }

  // ========== ELIMINAR ==========

  /// Elimina una transacción revirtiendo su efecto en saldos.
  Future<void> deleteTransaction(int id) async {
    final tx = await _txRepo.getById(id);
    if (tx == null) return;

    await _revertBalanceEffect(tx);
    await _txRepo.delete(id);
  }

  // ==========================================================
  // Efectos de saldo (privado)
  // ==========================================================

  Future<void> _applyBalanceEffect(AppTransaction tx) async {
    switch (tx.type) {
      case AppTransaction.typeIncome:
        await _applyBalanceDelta(tx.accountId, tx.amount, txCurrency: tx.currency);
        break;
      case AppTransaction.typeExpense:
        await _applyBalanceDelta(tx.accountId, -tx.amount, txCurrency: tx.currency);
        break;
      case AppTransaction.typeTransfer:
        final toId = tx.linkedAccountId;
        if (toId == null) return;

        // Origen: resta
        await _applyBalanceDelta(tx.accountId, -tx.amount, txCurrency: tx.currency);

        // Destino: suma convertida
        final destAcc = await _accountsRepo.getById(toId);
        final destCurrency = destAcc?.currency ?? tx.currency;
        double credit = tx.amount;
        if (destCurrency != tx.currency) {
          final rate = await _fx.getExchangeRate(tx.currency, destCurrency);
          credit = tx.amount * rate;
        }
        await _applyBalanceDelta(toId, credit, txCurrency: destCurrency);
        break;
      default:
      // nada
        break;
    }
  }

  Future<void> _revertBalanceEffect(AppTransaction tx) async {
    switch (tx.type) {
      case AppTransaction.typeIncome:
        await _applyBalanceDelta(tx.accountId, -tx.amount, txCurrency: tx.currency);
        break;
      case AppTransaction.typeExpense:
        await _applyBalanceDelta(tx.accountId, tx.amount, txCurrency: tx.currency);
        break;
      case AppTransaction.typeTransfer:
        final toId = tx.linkedAccountId;
        if (toId == null) return;

        // Revertir: origen suma
        await _applyBalanceDelta(tx.accountId, tx.amount, txCurrency: tx.currency);

        // Revertir: destino resta convertida
        final destAcc = await _accountsRepo.getById(toId);
        final destCurrency = destAcc?.currency ?? tx.currency;
        double debit = tx.amount;
        if (destCurrency != tx.currency) {
          final rate = await _fx.getExchangeRate(tx.currency, destCurrency);
          debit = tx.amount * rate;
        }
        await _applyBalanceDelta(toId, -debit, txCurrency: destCurrency);
        break;
      default:
        break;
    }
  }

  /// Aplica un cambio al balance de una cuenta, convirtiendo `change` a la moneda de la cuenta si fuera necesario.
  Future<void> _applyBalanceDelta(int accountId, double change, {required String txCurrency}) async {
    final acc = await _accountsRepo.getById(accountId);
    if (acc == null) return;

    // Convertir el cambio si la moneda del movimiento difiere de la de la cuenta
    double delta = change;
    if (acc.currency != txCurrency) {
      final rate = await _fx.getExchangeRate(txCurrency, acc.currency);
      delta = change * rate;
    }

    final newBalance = (acc.balance) + delta;
    final updated = acc.copyWith(balance: newBalance);
    await _accountsRepo.update(updated);

    if (kDebugMode) {
      print('Cuenta #$accountId: ${acc.balance} → $newBalance (${acc.currency})  [Δ=${delta.toStringAsFixed(2)}]');
    }
  }
}
