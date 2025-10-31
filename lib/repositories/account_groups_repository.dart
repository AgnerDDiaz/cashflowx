import 'package:sqflite/sqflite.dart';
import '../models/account_group.dart';
import '../utils/database_helper.dart';

class AccountGroupsRepository {
  final _dbHelper = DatabaseHelper();
  Future<Database> get _db async => await _dbHelper.database;

  Future<List<AccountGroup>> allOrdered() async {
    final db = await _db;
    final rows = await db.query('account_groups', orderBy: 'sort_order ASC, id ASC');
    return rows.map(AccountGroup.fromMap).toList();
  }

  Future<AccountGroup?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('account_groups', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AccountGroup.fromMap(rows.first);
  }

  Future<int> _nextSortOrder(Database db) async {
    final rows = await db.rawQuery('SELECT MAX(sort_order) as max_so FROM account_groups');
    final maxSo = (rows.first['max_so'] as int?) ?? 0;
    return maxSo + 1;
  }

  Future<AccountGroup> insert(AccountGroup g) async {
    final db = await _db;
    final id = await db.insert('account_groups', g.toMap());
    return g.copyWith(id: id);
  }

  Future<AccountGroup> insertWithName(String name) async {
    final db = await _db;
    final nextSo = await _nextSortOrder(db);
    final id = await db.insert('account_groups', {
      'name': name,
      'sort_order': nextSo,
      'collapsed': 0,
    });
    return AccountGroup(id: id, name: name, sortOrder: nextSo, collapsed: 0);
  }

  Future<void> update(AccountGroup g) async {
    if (g.id == null) return;
    final db = await _db;
    await db.update('account_groups', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
  }

  Future<void> reorder(List<int> orderedGroupIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedGroupIds.length; i++) {
        await txn.update('account_groups', {'sort_order': i}, where: 'id = ?', whereArgs: [orderedGroupIds[i]]);
      }
    });
  }

  Future<void> deleteAndMoveAccounts(int groupId) async {
    final db = await _db;
    final def = await db.query('account_groups', columns: ['id'], where: 'name = ?', whereArgs: ['General'], limit: 1);
    final generalId = (def.isNotEmpty) ? def.first['id'] as int : await db.insert('account_groups', {'name': 'General', 'sort_order': 0});
    await db.transaction((txn) async {
      await txn.update('accounts', {'group_id': generalId}, where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('account_groups', where: 'id = ?', whereArgs: [groupId]);
    });
  }
}
