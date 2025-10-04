import 'package:sqflite/sqflite.dart';
import '../models/transaction.dart';
import '../utils/database_helper.dart';

class TransactionsRepository {
  final _dbHelper = DatabaseHelper();
  Future<Database> get _db async => await _dbHelper.database;

  // ====== Lecturas básicas ======

  Future<List<AppTransaction>> all({String? orderBy}) async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      orderBy: orderBy ?? 'date DESC, id DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<AppTransaction?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AppTransaction.fromMap(rows.first);
  }

  Future<List<AppTransaction>> byAccount(
      int accountId, {
        String? fromIso, // 'YYYY-MM-DD'
        String? toIso,   // inclusive
        String? type,    // income | expense | transfer
        String? orderBy, // default: date DESC, id DESC
      }) async {
    final db = await _db;
    final where = <String>['account_id = ?'];
    final args = <Object>[accountId];

    if (fromIso != null) {
      where.add('date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      where.add('date <= ?');
      args.add(toIso);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }

    final rows = await db.query(
      'transactions',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: orderBy ?? 'date DESC, id DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  Future<List<AppTransaction>> byDateRange({
    required String fromIso,
    required String toIso,
    String? type, // income | expense | transfer
    int? categoryId,
  }) async {
    final db = await _db;
    final where = <String>['date >= ?', 'date <= ?'];
    final args = <Object>[fromIso, toIso];

    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }

    final rows = await db.query(
      'transactions',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(AppTransaction.fromMap).toList();
  }

  // ====== Escrituras básicas (CRUD) ======

  Future<AppTransaction> insert(AppTransaction t) async {
    final db = await _db;
    final id = await db.insert('transactions', t.toMap());
    return t.copyWith(id: id);
  }

  Future<void> update(AppTransaction t) async {
    if (t.id == null) return;
    final db = await _db;
    await db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ====== Agregaciones para reportes ======

  /// Suma por tipo (income/expense) en un rango de fechas. Útil para KPIs rápidos.
  Future<double> sumByType({
    required String type, // 'income' | 'expense'
    String? fromIso,
    String? toIso,
  }) async {
    final db = await _db;
    final where = <String>['type = ?'];
    final args = <Object>[type];

    if (fromIso != null) {
      where.add('date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      where.add('date <= ?');
      args.add(toIso);
    }

    final rows = await db.query(
      'transactions',
      columns: ['SUM(amount) as total'],
      where: where.join(' AND '),
      whereArgs: args,
    );

    final v = rows.first['total'] as num?;
    return (v ?? 0).toDouble();
  }

  /// Suma para una categoría **incluyendo** todas sus subcategorías (CTE recursivo).
  Future<double> sumByCategoryIncludingSubs({
    required int categoryId,
    required String type, // 'income' | 'expense'
    String? fromIso,
    String? toIso,
  }) async {
    final db = await _db;

    final dateConds = <String>[];
    final args = <Object>[categoryId, type];

    if (fromIso != null) {
      dateConds.add('t.date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      dateConds.add('t.date <= ?');
      args.add(toIso);
    }
    final dateSql = dateConds.isEmpty ? '' : 'AND ${dateConds.join(' AND ')}';

    final rows = await db.rawQuery('''
      WITH RECURSIVE subcats(id) AS (
        SELECT id FROM categories WHERE id = ?
        UNION ALL
        SELECT c.id
        FROM categories c
        JOIN subcats s ON c.parent_id = s.id
      )
      SELECT COALESCE(SUM(t.amount), 0) AS total
      FROM transactions t
      WHERE t.type = ?
        AND t.category_id IN (SELECT id FROM subcats)
        $dateSql
    ''', args);

    final v = rows.first['total'] as num?;
    return (v ?? 0).toDouble();
  }

  /// Totales por **subcategoría directa** de un padre (ideal para gráficos).
  Future<List<Map<String, dynamic>>> sumsPerSubcategory({
    required int parentCategoryId,
    required String type, // 'income' | 'expense'
    String? fromIso,
    String? toIso,
  }) async {
    final db = await _db;

    final conds = <String>[];
    final args = <Object>[type, parentCategoryId];

    if (fromIso != null) {
      conds.add('t.date >= ?');
      args.add(fromIso);
    }
    if (toIso != null) {
      conds.add('t.date <= ?');
      args.add(toIso);
    }

    final dateSql = conds.isEmpty ? '' : 'AND ${conds.join(' AND ')}';

    final rows = await db.rawQuery('''
      SELECT c.id   AS category_id,
             c.name AS category_name,
             COALESCE(SUM(t.amount), 0) AS total
      FROM categories c
      LEFT JOIN transactions t
        ON t.category_id = c.id
       AND t.type = ?
       $dateSql
      WHERE c.parent_id = ?
      GROUP BY c.id, c.name
      ORDER BY total DESC, c.name COLLATE NOCASE ASC
    ''', args);

    return rows.map((r) => {
      'category_id': r['category_id'],
      'category_name': r['category_name'],
      'total': (r['total'] as num?)?.toDouble() ?? 0.0,
    }).toList();
  }
}
