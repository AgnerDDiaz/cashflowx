import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../utils/database_helper.dart';

class AccountsRepository {
  final _dbHelper = DatabaseHelper();

  Future<Database> get _db async => await _dbHelper.database;

  /// Asegura que exista el grupo "General" y devuelve su id.
  Future<int> _ensureDefaultGroupId(Database db) async {
    final found = await db.query(
      'account_groups',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: ['General'],
      limit: 1,
    );
    if (found.isNotEmpty) return found.first['id'] as int;

    final insertedId = await db.insert(
      'account_groups',
      {'name': 'General', 'sort_order': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (insertedId != 0) return insertedId;

    final again = await db.query(
      'account_groups',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: ['General'],
      limit: 1,
    );
    if (again.isNotEmpty) return again.first['id'] as int;

    throw StateError('No fue posible asegurar el grupo "General".');
  }

  // ---------------- LECTURAS ----------------
  Future<List<Account>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      'accounts',
      orderBy: 'group_id ASC, sort_order ASC, id ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  Future<List<Account>> byGroupId(int groupId) async {
    final db = await _db;
    final rows = await db.query(
      'accounts',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  // ---------------- ESCRITURAS ----------------
  Future<Account> insert(Account a) async {
    final db = await _db;
    final data = a.toMap();
    if (data['group_id'] == null) {
      data['group_id'] = await _ensureDefaultGroupId(db);
    }

    // Calcular sort_order al final del grupo
    final maxRow = await db.rawQuery(
      'SELECT MAX(sort_order) as m FROM accounts WHERE group_id = ?',
      [data['group_id']],
    );
    final next = ((maxRow.first['m'] as int?) ?? -1) + 1;
    data['sort_order'] = next;

    final id = await db.insert('accounts', data);
    return a.copyWith(id: id, groupId: data['group_id'] as int?);
  }

  Future<void> update(Account a) async {
    if (a.id == null) return;
    final db = await _db;
    final data = a.toMap();
    if (data['group_id'] == null) {
      data['group_id'] = await _ensureDefaultGroupId(db);
    }
    await db.update(
      'accounts',
      data,
      where: 'id = ?',
      whereArgs: [a.id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  /// Cambia una cuenta de grupo (para mover entre grupos) y la coloca al final.
  Future<void> moveToGroup({required int accountId, required int groupId}) async {
    final db = await _dbHelper.database;
    final maxRow = await db.rawQuery(
      'SELECT MAX(sort_order) as m FROM accounts WHERE group_id = ?',
      [groupId],
    );
    final next = (maxRow.first['m'] as int? ?? -1) + 1;

    await db.update(
      'accounts',
      {'group_id': groupId, 'sort_order': next},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> updateSortOrdersInGroup(int groupId, List<int> accountIdsInNewOrder) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (int i = 0; i < accountIdsInNewOrder.length; i++) {
        await txn.update(
          'accounts',
          {'sort_order': i},
          where: 'id = ? AND group_id = ?',
          whereArgs: [accountIdsInNewOrder[i], groupId],
        );
      }
    });
  }

  // ---------------- UTILIDADES ----------------
  Future<double> totalVisibleIncludedBalance() async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT SUM(balance) as total FROM accounts WHERE visible = 1 AND include_in_balance = 1",
    );
    final v = rows.first['total'] as num?;
    return (v ?? 0).toDouble();
  }

  Future<void> toggleIncludeInBalance({
    required int accountId,
    required bool include,
  }) async {
    final db = await _db;
    await db.update(
      'accounts',
      {'include_in_balance': include ? 1 : 0},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  Future<void> deleteAccount(int accountId) async {
    final db = await _db;
    await db.delete('accounts', where: 'id = ?', whereArgs: [accountId]);
  }

  /// Devuelve cuentas de un grupo con orden por sort_order ASC, id ASC.
  Future<List<Account>> getByGroupOrdered(int groupId) async {
    final db = await _db;
    final rows = await db.query(
      'accounts',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(Account.fromMap).toList();
  }
}

// Helpers convenientes
extension AccountsRepoHelpers on AccountsRepository {
  Future<List<Account>> visibleOnly() async {
    final all = await getAll();
    return all.where((a) => a.visible == 1).toList();
  }

  Future<List<Account>> includedInTotal() async {
    final all = await getAll();
    return all.where((a) => a.visible == 1 && a.includeInBalance == 1).toList();
  }
}
