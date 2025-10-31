import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../models/account.dart';
import '../models/account_group.dart';
import '../models/credit_card_meta.dart';
import '../models/transaction.dart';

import '../repositories/transactions_repository.dart';
import '../repositories/credit_cards_repository.dart';

import '../utils/database_helper.dart';
import 'account_card.dart';
import 'credit_card_account_card.dart';
import 'money_text.dart';

class AccountGroupSection extends StatefulWidget {
  final AccountGroup group;
  final List<Account> accounts;
  final String mainCurrency;

  final bool editMode;
  final Function(Account) onTapAccount;
  final Future<void> Function(List<int> newOrderIds)? onReorderConfirmed;
  final Future<void> Function(Account a)? onToggleInclude;
  final Future<void> Function(Account a)? onDelete;
  final Future<void> Function(Account a)? onMoveToGroup;

  const AccountGroupSection({
    super.key,
    required this.group,
    required this.accounts,
    required this.mainCurrency,
    required this.onTapAccount,
    required this.editMode,
    this.onReorderConfirmed,
    this.onToggleInclude,
    this.onDelete,
    this.onMoveToGroup,
  });

  @override
  State<AccountGroupSection> createState() => _AccountGroupSectionState();
}

class _AccountGroupSectionState extends State<AccountGroupSection> {
  final _cardsRepo = CreditCardsRepository();
  final _txRepo = TransactionsRepository();

  int? _parseDay(String? s) {
    if (s == null) return null;
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt.day.clamp(1, 28);
    final onlyDigits = RegExp(r'\d+').stringMatch(s);
    final n = int.tryParse(onlyDigits ?? '');
    return n == null ? null : n.clamp(1, 28);
  }

  double _sumCycle(List<AppTransaction> txs) {
    double s = 0;
    for (final t in txs) {
      if (t.type == AppTransaction.typeExpense) s += t.amount;
      else if (t.type == AppTransaction.typeIncome) s -= t.amount;
    }
    return s;
  }

  Future<CreditCardMeta> _computeMetaFromTx(Account a) async {
    final today = DateTime.now();
    final cutoffDay = (_parseDay(a.cutoffDate) ?? 1).clamp(1, 28);

    DateTime lastCut = DateTime(today.year, today.month, cutoffDay);
    if (today.day < cutoffDay) {
      final prev = DateTime(today.year, today.month - 1, 1);
      lastCut = DateTime(prev.year, prev.month, cutoffDay);
    }
    final nextCut = DateTime(lastCut.year, lastCut.month + 1, cutoffDay);
    final nextNextCut = DateTime(nextCut.year, nextCut.month + 1, cutoffDay);

    String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

    final from1 = _iso(lastCut);
    final to1 = _iso(nextCut.subtract(const Duration(days: 1)));
    final from2 = _iso(nextCut);
    final to2 = _iso(nextNextCut.subtract(const Duration(days: 1)));

    final txCycle = await _txRepo.byAccount(a.id!, fromIso: from1, toIso: to1);
    final txPost = await _txRepo.byAccount(a.id!, fromIso: from2, toIso: to2);

    final statement = _sumCycle(txCycle);
    final post = _sumCycle(txPost);

    return CreditCardMeta(
      accountId: a.id!,
      statementDay: cutoffDay,
      dueDay: _parseDay(a.dueDate),
      statementDue: statement,
      postStatement: post,
      creditLimit: a.maxCredit,
    );
  }

  Future<CreditCardMeta> _loadCreditMeta(Account a) async {
    final meta = await _cardsRepo.getMeta(a.id!);
    if (meta != null) {
      return meta.copyWith(
        statementDay: meta.statementDay ?? _parseDay(a.cutoffDate),
        dueDay: meta.dueDay ?? _parseDay(a.dueDate),
        creditLimit: meta.creditLimit ?? a.maxCredit,
      );
    }
    return _computeMetaFromTx(a);
  }

  Future<double?> _rate(String from, String to) async {
    if (from == to) return 1.0;
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'exchange_rates',
      columns: ['rate'],
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [from, to],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first['rate'];
    if (r is num) return r.toDouble();
    return double.tryParse('$r');
  }

  Future<(double included, double excluded)> _groupConvertedTotals(List<Account> accounts) async {
    double inc = 0, exc = 0;
    for (final a in accounts) {
      if (a.visible != 1) continue;
      final rate = await _rate(a.currency, widget.mainCurrency);
      if (rate == null || rate <= 0) continue;
      final amt = a.balance * rate;
      if (a.includeInBalance == 1) inc += amt; else exc += amt;
    }
    return (inc, exc);
  }

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: DragTarget<Account>(
        onWillAcceptWithDetails: (details) => true,                       // ✅
        onAcceptWithDetails: (details) async {                            // ✅
          final acc = details.data;
          if (widget.onMoveToGroup != null) {
            await widget.onMoveToGroup!(acc);
          }
        },
        builder: (context, candidate, rejected) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  widget.group.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              FutureBuilder<(double inc, double exc)>(
                future: _groupConvertedTotals(widget.accounts),
                builder: (context, snap) {
                  final data = snap.data ?? (0.0, 0.0);
                  final inc = data.$1;
                  final exc = data.$2;
                  final f = NumberFormat.currency(locale: 'en_US', symbol: '${widget.mainCurrency} ');
                  final neutral = Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(
                        text: f.format(inc),
                        rawAmount: inc,
                        positiveIsGood: true,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      if (exc.abs() > 0.0001)
                        Text('No incl.: ${f.format(exc)}', style: TextStyle(fontSize: 12, color: neutral)),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    if (widget.editMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          _buildEditableList(context),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        _buildCards(context),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildEditableList(BuildContext context) {
    if (widget.accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Sin cuentas aquí aún'),
        ),
      );
    }

    final children = List<Widget>.generate(widget.accounts.length, (i) {
      final a = widget.accounts[i];

      final tile = ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: IconButton(
          tooltip: 'Eliminar',
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: () async => widget.onDelete?.call(a),
        ),
        title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: (a.includeInBalance == 1) ? 'Ocultar de totales' : 'Incluir en totales',
              icon: Icon((a.includeInBalance == 1) ? Icons.visibility : Icons.visibility_off),
              onPressed: () async => widget.onToggleInclude?.call(a),
            ),
            ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
        onTap: () {},
      );

      return LongPressDraggable<Account>(
        key: ValueKey('acc_${a.id}'),   // ✅ requerido por ReorderableListView
        data: a,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Opacity(opacity: 0.85, child: tile),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: tile),
        child: tile,
      );
      
    });

    return DragTarget<Account>(
      onWillAcceptWithDetails: (details) => true,                       // ✅
      onAcceptWithDetails: (details) async {                            // ✅
        final a = details.data;
        if (!widget.accounts.any((x) => x.id == a.id)) {
          await widget.onMoveToGroup?.call(a);
          setState(() {});
        }
      },
      builder: (context, candidate, rejected) {
        return ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (oldIndex, newIndex) async {
            final tmp = [...widget.accounts];
            if (newIndex > oldIndex) newIndex--;
            final item = tmp.removeAt(oldIndex);
            tmp.insert(newIndex, item);
            await widget.onReorderConfirmed?.call(tmp.map((e) => e.id!).toList());
            setState(() {});
          },
          children: children,
        );
      },
    );

  }

  Widget _buildCards(BuildContext context) {
    if (widget.accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(
          'Sin cuentas aquí aún',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).disabledColor,
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 4),
        ...widget.accounts.map((a) => _buildAccountCard(context, a)).toList(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAccountCard(BuildContext context, Account a) {
    if (a.visible == 0) return const SizedBox.shrink();

    if (a.type == 'credit') {
      return FutureBuilder<CreditCardMeta>(
        future: _loadCreditMeta(a),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final meta = snap.data!;
          return CreditCardAccountCard(
            account: a,
            meta: meta,
            mainCurrency: widget.mainCurrency, // ← NUEVO
            onTap: () => widget.onTapAccount(a),
          );

        },
      );
    }

    return AccountCard(
      account: a,
      mainCurrency: widget.mainCurrency,
      onTap: () => widget.onTapAccount(a),
    );
  }
}
