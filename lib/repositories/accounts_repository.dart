import 'package:sqflite/sqflite.dart';
import '../models/account.dart';
import '../utils/database_helper.dart';

class AccountsRepository {
  final _dbHelper = DatabaseHelper();

  Future<Database> get _db async => await _dbHelper.database;

  /// Asegura que exista el grupo "General" y devuelve su id.
  Future<int> _ensureDefaultGroupId(Database db) async {
    // Intentar encontrarlo primero
    final found = await db.query(
      'account_groups',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: ['General'],
      limit: 1,
    );
    if (found.isNotEmpty) return found.first['id'] as int;

    // Crearlo si no existe (la tabla tiene UNIQUE(name))
    final id = await db.insert(
      'account_groups',
      {'name': 'General', 'sort_order': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    if (id != 0) return id; // insert nuevo

    // Si otro hilo/proceso lo creó al mismo tiempo, búscalo de nuevo
    final again = await db.query(
      'account_groups',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: ['General'],
      limit: 1,
    );
    if (again.isNotEmpty) return again.first['id'] as int;

    // Fallback defensivo
    throw StateError('No fue posible asegurar el grupo "General".');
  }

  Future<List<Account>> getAll() async {
    final db = await _db;
    final rows = await db.query('accounts', orderBy: 'group_id ASC, id DESC');
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
      orderBy: 'id DESC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<Account> insert(Account a) async {
    final db = await _db;

    // Garantizar group_id (si viene null lo asignamos a "General")
    final data = a.toMap();
    if (data['group_id'] == null) {
      data['group_id'] = await _ensureDefaultGroupId(db);
    }

    final id = await db.insert('accounts', data);
    return a.copyWith(id: id, groupId: data['group_id'] as int?);
  }

  Future<void> update(Account a) async {
    if (a.id == null) return;
    final db = await _db;

    // Si te llega groupId null, igualmente no romperá gracias a los triggers de BD,
    // pero aquí lo reforzamos para evitar un UPDATE extra.
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

  /// Cambia una cuenta de grupo (útil para drag & drop entre grupos en la UI).
  Future<void> moveToGroup({required int accountId, required int groupId}) async {
    final db = await _db;
    await db.update(
      'accounts',
      {'group_id': groupId},
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  /// Suma el balance de todas las cuentas visibles e incluidas en balance.
  Future<double> totalVisibleIncludedBalance() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT SUM(balance) as total
      FROM accounts
      WHERE visible = 1 AND include_in_balance = 1
    ''');
    final v = rows.first['total'] as num?;
    return (v ?? 0).toDouble();
  }
}
