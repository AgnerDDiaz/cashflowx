import 'package:sqflite/sqflite.dart';
import '../models/account_group.dart';
import '../utils/database_helper.dart';

class AccountGroupsRepository {
  final _dbHelper = DatabaseHelper();
  Future<Database> get _db async => await _dbHelper.database;

  // ✅ Obtener todos los grupos
  Future<List<AccountGroup>> getAll() async {
    final db = await _db;
    final rows = await db.query('account_groups', orderBy: 'sort_order ASC, id ASC');
    return rows.map(AccountGroup.fromMap).toList();
  }

  // ✅ Obtener un grupo por ID
  Future<AccountGroup?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('account_groups', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return AccountGroup.fromMap(rows.first);
  }

  // ✅ Insertar nuevo grupo
  Future<AccountGroup> insert(AccountGroup g) async {
    final db = await _db;
    final id = await db.insert('account_groups', g.toMap());
    return g.copyWith(id: id);
  }

  // ✅ Actualizar grupo existente
  Future<void> update(AccountGroup g) async {
    if (g.id == null) return;
    final db = await _db;
    await db.update('account_groups', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
  }

  // ✅ Eliminar grupo
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('account_groups', where: 'id = ?', whereArgs: [id]);
  }
}
