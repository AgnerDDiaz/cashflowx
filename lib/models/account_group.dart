import 'package:sqflite/sqflite.dart';
import '../models/account_group.dart';
import '../utils/database_helper.dart';

class AccountGroup {
  final int? id;
  final String name;
  final int sortOrder;
  final String? color;
  final int collapsed; // 0 o 1

  const AccountGroup({
    this.id,
    required this.name,
    this.sortOrder = 0,
    this.color,
    this.collapsed = 0,
  });

  factory AccountGroup.fromMap(Map<String, dynamic> map) => AccountGroup(
    id: map['id'] as int?,
    name: (map['name'] ?? '') as String,
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    color: map['color'] as String?,
    collapsed: (map['collapsed'] as int?) ?? 0,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'sort_order': sortOrder,
    'color': color,
    'collapsed': collapsed,
  };

  AccountGroup copyWith({
    int? id,
    String? name,
    int? sortOrder,
    String? color,
    int? collapsed,
  }) =>
      AccountGroup(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
        color: color ?? this.color,
        collapsed: collapsed ?? this.collapsed,
      );
}

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

  Future<AccountGroup> insert(AccountGroup g) async {
    final db = await _db;
    final id = await db.insert('account_groups', g.toMap());
    return g.copyWith(id: id);
  }

  Future<void> update(AccountGroup g) async {
    if (g.id == null) return;
    final db = await _db;
    await db.update('account_groups', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
  }

  // Reordena según la lista recibida (posición = sort_order)
  Future<void> reorder(List<int> orderedGroupIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (int i = 0; i < orderedGroupIds.length; i++) {
        await txn.update('account_groups', {'sort_order': i}, where: 'id = ?', whereArgs: [orderedGroupIds[i]]);
      }
    });
  }

  // Eliminar grupo y mover sus cuentas a "General"
  Future<void> deleteAndMoveAccounts(int groupId) async {
    final db = await _db;

    // Asegurar id del grupo General
    final def = await db.query('account_groups', columns: ['id'], where: 'name = ?', whereArgs: ['General'], limit: 1);
    final generalId = (def.isNotEmpty) ? def.first['id'] as int : await db.insert('account_groups', {'name': 'General', 'sort_order': 0});

    await db.transaction((txn) async {
      await txn.update('accounts', {'group_id': generalId}, where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('account_groups', where: 'id = ?', whereArgs: [groupId]);
    });
  }
}