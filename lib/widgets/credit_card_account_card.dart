import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/credit_card_meta.dart';
import '../services/credit_card_calculator.dart';
import '../utils/database_helper.dart';
import 'money_text.dart';

class CreditCardAccountCard extends StatelessWidget {
  final Account account;
  final CreditCardMeta meta;
  final String mainCurrency; // ← NUEVO: para mostrar la ≈ conversión del total
  final VoidCallback? onTap;

  const CreditCardAccountCard({
    super.key,
    required this.account,
    required this.meta,
    required this.mainCurrency,
    this.onTap,
  });

  Future<double?> _getRate(String from, String to) async {
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

  @override
  Widget build(BuildContext context) {
    final symbol = account.currency;
    final f = NumberFormat.currency(locale: 'en_US', symbol: '$symbol ');
    final usedMeta = (meta.statementDue != 0.0 || meta.postStatement != 0.0);

    final excluded = account.includeInBalance == 0;
    final baseColor = Theme.of(context).cardColor;
    // Oscurecer un poco la card si está excluida del balance
    final cardColor =
    excluded ? Color.alphaBlend(Colors.black.withOpacity(0.15), baseColor) : baseColor;
    final neutral = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.55);

    // El “fondo” que me pediste para los recuadros
    final pillBg = Theme.of(context).scaffoldBackgroundColor;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FutureBuilder<CreditCardCycleTotals>(
          future: usedMeta
              ? Future.value(
            CreditCardCycleTotals(
              statementDue: meta.statementDue,
              postStatement: meta.postStatement,
              statementDay: meta.statementDay ?? 1,
              dueDay: meta.dueDay,
            ),
          )
              : CreditCardCalculator().compute(account),
          builder: (context, snap) {
            final data = snap.data;
            final statement = data?.statementDue ?? 0.0;
            final post = data?.postStatement ?? 0.0;
            final dueDay = data?.dueDay ?? meta.dueDay;
            final totalBalance = statement + post;
            final headerText = 'Paga el ${dueDay ?? '—'}';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado: nombre + “Paga el …” a la izquierda / total a la derecha
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            headerText,
                            style: TextStyle(
                              fontSize: 12,
                              color: (excluded ? neutral : Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withOpacity(0.8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Total + ≈ conversión debajo (alineado a la derecha)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(
                          text: f.format(totalBalance),
                          rawAmount: totalBalance,
                          positiveIsGood: false,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                          colorOverride: excluded ? neutral : null,
                        ),
                        const SizedBox(height: 3),
                        FutureBuilder<double?>(
                          future: _getRate(account.currency, mainCurrency),
                          builder: (context, ss) {
                            if (account.currency == mainCurrency) {
                              return const SizedBox.shrink();
                            }
                            String mini;
                            if (ss.connectionState == ConnectionState.waiting) {
                              mini = '≈ —';
                            } else {
                              final rate = ss.data;
                              if (rate == null || rate <= 0) {
                                mini = '≈ —';
                              } else {
                                final mf = NumberFormat.currency(
                                  locale: 'en_US',
                                  symbol: '$mainCurrency ',
                                );
                                mini = '≈ ${mf.format(totalBalance * rate)}';
                              }
                            }
                            return Text(
                              mini,
                              style: TextStyle(fontSize: 12, color: neutral),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Recuadros “Este ciclo / Próximo ciclo” con color de fondo
                Row(
                  children: [
                    Expanded(
                      child: _pill(
                        context,
                        background: pillBg,
                        title: 'Este ciclo',
                        titleColor: excluded ? neutral : null,
                        child: MoneyText(
                          text: f.format(statement),
                          rawAmount: statement,
                          positiveIsGood: false,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          colorOverride: excluded ? neutral : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pill(
                        context,
                        background: pillBg,
                        title: 'Próximo ciclo',
                        titleColor: excluded ? neutral : null,
                        child: MoneyText(
                          text: f.format(post),
                          rawAmount: post,
                          positiveIsGood: false,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          colorOverride: excluded ? neutral : null,
                        ),
                      ),
                    ),
                  ],
                ),

                if (meta.creditLimit != null) ...[
                  const SizedBox(height: 10),
                  _availableCreditLine(
                    context: context,
                    f: f,
                    usedTotal: totalBalance,
                    neutral: neutral,
                    dim: excluded,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pill(
      BuildContext context, {
        required String title,
        required Color background,
        Color? titleColor,
        required Widget child,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: titleColor ??
                  Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _availableCreditLine({
    required BuildContext context,
    required NumberFormat f,
    required double usedTotal,
    required Color? neutral,
    required bool dim,
  }) {
    final limit = meta.creditLimit!;
    final available = usedTotal > 0 ? (limit - usedTotal) : limit;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Crédito disponible',
          style: TextStyle(
            fontSize: 12,
            color: dim
                ? neutral
                : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.9),
          ),
        ),
        MoneyText(
          text: f.format(available),
          rawAmount: available,
          positiveIsGood: true,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          colorOverride: dim ? neutral : null,
        ),
      ],
    );
  }
}
