// lib/repositories/scheduled_transactions_repository.dart
import 'package:sqflite/sqflite.dart';
import '../utils/database_helper.dart';
import '../models/scheduled_transaction.dart';

class ScheduledTransactionsRepository {
  final _dbHelper = DatabaseHelper();

  Future<int> insert(ScheduledTransaction s) async {
    final db = await _dbHelper.database;
    return db.insert('scheduled_transactions', s.toMap());
  }

  Future<int> update(ScheduledTransaction s) async {
    final db = await _dbHelper.database;
    return db.update(
      'scheduled_transactions',
      s.toMap(),
      where: 'id = ?',
      whereArgs: [s.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.delete('scheduled_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<ScheduledTransaction?> getById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('scheduled_transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ScheduledTransaction.fromMap(rows.first);
  }

  Future<List<ScheduledTransaction>> all({String orderBy = 'next_run ASC'}) async {
    final db = await _dbHelper.database;
    final rows = await db.query('scheduled_transactions', orderBy: orderBy);
    return rows.map(ScheduledTransaction.fromMap).toList();
  }

  /// Solo activas y con next_run <= todayIso
  Future<List<ScheduledTransaction>> allDue(String todayIso) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'scheduled_transactions',
      where: 'is_active = 1 AND next_run <= ?',
      whereArgs: [todayIso],
      orderBy: 'next_run ASC',
    );
    return rows.map(ScheduledTransaction.fromMap).toList();
  }

  Future<void> toggleActive(int id, bool active) async {
    final db = await _dbHelper.database;
    await db.update(
      'scheduled_transactions',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
