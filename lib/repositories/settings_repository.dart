import 'package:sqflite/sqflite.dart';
import '../models/setting.dart';
import '../utils/database_helper.dart';

class SettingsRepository {
  final _dbHelper = DatabaseHelper();
  Future<Database> get _db async => await _dbHelper.database;

  Future<AppSettings> getSettings() async {
    final db = await _db;
    final rows = await db.query('settings', limit: 1);
    if (rows.isEmpty) {
      // fallback si por algo no existe la fila
      final defaultRow = {
        'main_currency': 'USD',
        'secondary_currency': 'DOP',
        'first_day_of_week': 'monday',
        'first_day_of_month': '1st',
        'default_view': 'weekly',
        'backup_enabled': 0,
        'notifications': 1,
        'theme_mode': 'system',
        'language': 'es',
        'biometric_enabled': 0,
        'pin_code': null,
        'auto_update_rates': 1,
        'rate_update_interval_days': 30,
      };
      final id = await db.insert('settings', defaultRow);
      return AppSettings.fromMap({...defaultRow, 'id': id});
    }
    return AppSettings.fromMap(rows.first);
  }

  Future<void> updateSettings(AppSettings settings) async {
    final db = await _db;
    await db.update('settings', settings.toMap(), where: 'id = ?', whereArgs: [settings.id ?? 1]);
  }

  /// Update de una sola clave (equivalente a `updateSetting` viejo).
  Future<void> updateKey(String column, dynamic value) async {
    const valid = {
      'main_currency',
      'first_day_of_week',
      'first_day_of_month',
      'default_view',
      'backup_enabled',
      'notifications',
      'secondary_currency',
      'theme_mode',
      'language',
      'biometric_enabled',
      'pin_code',
      'auto_update_rates',
      'rate_update_interval_days',
    };
    if (!valid.contains(column)) {
      throw ArgumentError('Clave de configuración no válida: $column');
    }
    final db = await _db;
    await db.update('settings', {column: value}, where: 'id = ?', whereArgs: [1]);
  }
}
