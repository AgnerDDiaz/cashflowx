import 'package:sqflite/sqflite.dart';
import '../models/credit_card_meta.dart';
import '../utils/database_helper.dart';

class CreditCardsRepository {
  final _dbHelper = DatabaseHelper();
  Future<Database> get _db async => await _dbHelper.database;

  Future<CreditCardMeta?> getMeta(int accountId) async {
    final db = await _db;
    final rows = await db.query('credit_cards_meta', where: 'account_id = ?', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) return null;
    return CreditCardMeta.fromMap(rows.first);
  }

  Future<void> upsertMeta(CreditCardMeta meta) async {
    final db = await _db;
    await db.insert('credit_cards_meta', meta.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}