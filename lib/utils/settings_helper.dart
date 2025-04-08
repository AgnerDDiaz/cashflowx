import 'package:cashflowx/utils/database_helper.dart';

class SettingsHelper {
  static final SettingsHelper _instance = SettingsHelper._internal();
  factory SettingsHelper() => _instance;

  SettingsHelper._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

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
}
