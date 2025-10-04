import 'package:sqflite/sqflite.dart';
import '../models/exchange_rate.dart';
import '../utils/database_helper.dart';

class ExchangeRatesRepository {
  final _dbHelper = DatabaseHelper();
  Future<Database> get _db async => await _dbHelper.database;

  Future<double?> getDirectRate(String base, String target) async {
    final db = await _db;
    final rows = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [base, target],
      orderBy: 'last_updated DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['rate'] as num).toDouble();
  }

  Future<double?> getRateOrInverse(String from, String to) async {
    final direct = await getDirectRate(from, to);
    if (direct != null) return direct;

    final inverse = await getDirectRate(to, from);
    if (inverse != null && inverse > 0) return 1.0 / inverse;

    return null;
  }

  Future<void> upsert(String base, String target, double rate, {String? lastUpdated}) async {
    final db = await _db;
    final today = (lastUpdated ?? DateTime.now().toIso8601String().substring(0, 10));
    final updated = await db.update(
      'exchange_rates',
      {'rate': rate, 'last_updated': today},
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [base, target],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    if (updated == 0) {
      await db.insert('exchange_rates', {
        'base_currency': base,
        'target_currency': target,
        'rate': rate,
        'last_updated': today,
      });
    }
  }

  Future<List<ExchangeRate>> all() async {
    final db = await _db;
    final rows = await db.query('exchange_rates', orderBy: 'base_currency ASC, target_currency ASC');
    return rows.map(ExchangeRate.fromMap).toList();
  }

  Future<List<String>> allCurrencies() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT DISTINCT base_currency AS code FROM exchange_rates
      UNION
      SELECT DISTINCT target_currency AS code FROM exchange_rates
    ''');
    return result.map((r) => r['code'] as String).toList();
  }

  Future<List<String>> allBaseCurrencyCodes() async {
    final db = await _db;
    final rows = await db.query('exchange_rates', columns: ['base_currency'], distinct: true);
    return rows.map((r) => r['base_currency'] as String).toList();
  }

  Future<void> logManual(String from, String to, double rate) async {
    final db = await _db;
    await db.insert('custom_exchange_rates_log', {
      'base_currency': from,
      'target_currency': to,
      'rate': rate,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> manualLog() async {
    final db = await _db;
    return await db.query('custom_exchange_rates_log', orderBy: 'updated_at DESC');
  }
}
