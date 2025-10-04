import 'package:sqflite/sqflite.dart';
import '../models/category.dart';
import '../utils/database_helper.dart';

class CategoriesRepository {
  final _dbHelper = DatabaseHelper();

  Future<Database> get _db async => await _dbHelper.database;

  /// Obtener todas las categorías (opcionalmente filtradas por tipo).
  Future<List<Category>> getAll({String? type}) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'parent_id ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// Obtener solo las categorías principales (sin padre)
  Future<List<Category>> getMain({String? type}) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: type == null ? 'parent_id IS NULL' : 'parent_id IS NULL AND type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// Obtener las subcategorías de una categoría padre
  Future<List<Category>> getSubcategories(int parentId) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  /// Obtener una categoría por ID
  Future<Category?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  /// Insertar una nueva categoría
  Future<Category> insert(Category c) async {
    final db = await _db;
    final id = await db.insert(
      'categories',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return c.copyWith(id: id == 0 ? null : id);
  }

  /// Actualizar una categoría existente
  Future<void> update(Category c) async {
    if (c.id == null) return;
    final db = await _db;
    await db.update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  /// Eliminar categoría (y sus subcategorías si existen)
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// Buscar categoría por nombre exacto
  Future<Category?> findByName(String name, {String? type}) async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: type == null ? 'name = ?' : 'name = ? AND type = ?',
      whereArgs: type == null ? [name] : [name, type],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  /// Devuelve todas las categorías con sus subcategorías agrupadas
  Future<Map<Category, List<Category>>> getGroupedByParent({String? type}) async {
    final mains = await getMain(type: type);
    final grouped = <Category, List<Category>>{};
    for (final parent in mains) {
      final subs = await getSubcategories(parent.id!);
      grouped[parent] = subs;
    }
    return grouped;
  }
}
