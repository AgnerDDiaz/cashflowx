import 'package:cashflowx/utils/database_helper.dart';

class SettingsHelper {
  static final SettingsHelper _instance = SettingsHelper._internal();
  factory SettingsHelper() => _instance;

  SettingsHelper._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // -------- Moneda principal (lo que ya tenías) --------

  /// ✅ Obtener la moneda principal actual
  Future<String> getMainCurrency() async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'settings',
      columns: ['main_currency'],
      where: 'id = 1', // Tu settings siempre tiene id = 1
    );

    if (result.isNotEmpty && result.first['main_currency'] != null) {
      return result.first['main_currency'] as String;
    } else {
      // Si por alguna razón no existe, inicializamos a 'DOP'
      await setMainCurrency('DOP');
      return 'DOP';
    }
  }

  /// ✅ Cambiar la moneda principal
  Future<void> setMainCurrency(String newCurrency) async {
    final db = await _dbHelper.database;

    await db.update(
      'settings',
      {'main_currency': newCurrency},
      where: 'id = 1',
    );
  }

  // -------- Primer día de la semana (NUEVO) --------

  static const String _kFirstWeekdayCol = 'first_day_of_week'; // 'monday' | 'sunday'

  /// Asegura que la columna exista (si es proyecto viejo, la crea al vuelo).
  Future<void> _ensureFirstWeekdayColumn() async {
    final db = await _dbHelper.database;

    // ¿Ya existe la columna?
    final info = await db.rawQuery("PRAGMA table_info(settings);");
    final exists = info.any((c) => (c['name'] as String?) == _kFirstWeekdayCol);
    if (exists) return;

    // Crear columna con default 'monday' y setear fila id=1 si existe.
    await db.execute(
      "ALTER TABLE settings ADD COLUMN $_kFirstWeekdayCol TEXT DEFAULT 'monday';",
    );

    // Si la fila id=1 ya existe, garantizar valor.
    await db.update(
      'settings',
      {_kFirstWeekdayCol: 'monday'},
      where: 'id = 1',
    );
  }

  /// ✅ Obtener primer día de la semana. Siempre devuelve 'monday' o 'sunday'.
  Future<String> getFirstWeekday() async {
    await _ensureFirstWeekdayColumn();
    final db = await _dbHelper.database;

    final result = await db.query(
      'settings',
      columns: [_kFirstWeekdayCol],
      where: 'id = 1',
      limit: 1,
    );

    final value = (result.isNotEmpty ? result.first[_kFirstWeekdayCol] : null) as String?;
    if (value == 'sunday') return 'sunday';
    return 'monday'; // default
  }

  /// ✅ Establecer primer día de la semana ('monday' | 'sunday')
  Future<void> setFirstWeekday(String value) async {
    final v = (value.toLowerCase() == 'sunday') ? 'sunday' : 'monday'; // solo 2 valores permitidos
    await _ensureFirstWeekdayColumn();
    final db = await _dbHelper.database;

    await db.update(
      'settings',
      {_kFirstWeekdayCol: v},
      where: 'id = 1',
    );
  }
}
