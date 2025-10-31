import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import 'money_text.dart';
import '../utils/database_helper.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final String mainCurrency;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.account,
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
    final numberFmt = NumberFormat.currency(locale: 'en_US', symbol: '$symbol ');
    final formatted = numberFmt.format(account.balance);
    final positiveIsGood = (account.type == 'debt') ? false : true;

    final excluded = account.includeInBalance == 0;
    final baseColor = Theme.of(context).cardColor;
    final cardColor = excluded
        ? Color.alphaBlend(Colors.black.withOpacity(0.15), baseColor)
        : baseColor;
    final neutral = Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.55);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                account.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  text: formatted,
                  rawAmount: account.balance,
                  positiveIsGood: positiveIsGood,
                  colorOverride: excluded ? neutral : null,
                ),
                const SizedBox(height: 3),
                FutureBuilder<double?>(
                  future: _getRate(account.currency, mainCurrency),
                  builder: (context, snapshot) {
                    if (account.currency == mainCurrency) return const SizedBox.shrink();
                    String text;
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      text = '≈ —';
                    } else {
                      final rate = snapshot.data;
                      if (rate == null || rate <= 0) {
                        text = '≈ —';
                      } else {
                        final mainFmt = NumberFormat.currency(locale: 'en_US', symbol: '$mainCurrency ');
                        final converted = account.balance * rate;
                        text = '≈ ${mainFmt.format(converted)}';
                      }
                    }
                    return Text(
                      text,
                      style: TextStyle(fontSize: 12, color: neutral),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
