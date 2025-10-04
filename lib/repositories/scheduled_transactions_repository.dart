import 'package:sqflite/sqflite.dart';
import '../models/scheduled_transaction.dart';
import '../utils/database_helper.dart';

class ScheduledTransactionsRepository {
  final _dbHelper = DatabaseHelper();
  Future<Database> get _db async => await _dbHelper.database;

  Future<List<ScheduledTransaction>> all() async {
    final db = await _db;
    final rows = await db.query('scheduled_transactions', orderBy: 'next_run ASC, id ASC');
    return rows.map(ScheduledTransaction.fromMap).toList();
  }

  Future<ScheduledTransaction?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('scheduled_transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ScheduledTransaction.fromMap(rows.first);
  }

  Future<ScheduledTransaction> insert(ScheduledTransaction s) async {
    final db = await _db;
    final id = await db.insert('scheduled_transactions', s.toMap());
    return s.copyWith(id: id);
  }

  Future<void> update(ScheduledTransaction s) async {
    if (s.id == null) return;
    final db = await _db;
    await db.update('scheduled_transactions', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('scheduled_transactions', where: 'id = ?', whereArgs: [id]);
  }
}

