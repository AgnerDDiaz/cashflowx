import 'package:flutter/material.dart';
import 'package:cashflowx/utils/database_helper.dart';

class SettingsHelper {
  static final SettingsHelper _instance = SettingsHelper._internal();
  factory SettingsHelper() => _instance;
  SettingsHelper._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // =================== THEME & LANGUAGE (NUEVO) ===================

  static const String _kThemeModeCol   = 'theme_mode';     // 'system' | 'light' | 'dark'
  static const String _kLanguageCodeCol= 'language_code';  // 'system' | 'en' | 'es' ...

  /// Notifier para reconstruir la app cuando cambie el tema.
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Carga tema/idioma desde BD al iniciar la app (llamar en main() antes de runApp).
  Future<void> loadThemeAndLanguage() async {
    await _ensureThemeLanguageColumns();

    // Tema
    final tm = await _getStringSetting(_kThemeModeCol, 'system');
    themeMode.value = _parseThemeMode(tm);

    // Idioma (no usamos notifier; lo aplica SettingsScreen con EasyLocalization)
    // Si quieres leerlo en runtime:
    // final lang = await _getStringSetting(_kLanguageCodeCol, 'system');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final db = await _dbHelper.database;
    await db.update('settings', { _kThemeModeCol: _themeModeToString(mode) }, where: 'id = 1');
    themeMode.value = mode;
  }

  Future<ThemeMode> getThemeMode() async {
    final s = await _getStringSetting(_kThemeModeCol, 'system');
    return _parseThemeMode(s);
  }

  Future<void> setLanguageCode(String code) async {
    final db = await _dbHelper.database;
    await db.update('settings', { _kLanguageCodeCol: code }, where: 'id = 1');
  }

  Future<String> getLanguageCode() async {
    return _getStringSetting(_kLanguageCodeCol, 'system');
  }

  ThemeMode _parseThemeMode(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark' : return ThemeMode.dark;
      default     : return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light: return 'light';
      case ThemeMode.dark : return 'dark';
      case ThemeMode.system:
      default             : return 'system';
    }
  }

  Future<void> _ensureThemeLanguageColumns() async {
    final db = await _dbHelper.database;
    final info = await db.rawQuery("PRAGMA table_info(settings);");

    bool has(String name) => info.any((c) => (c['name'] as String?) == name);

    if (!has(_kThemeModeCol)) {
      await db.execute("ALTER TABLE settings ADD COLUMN $_kThemeModeCol TEXT DEFAULT 'system';");
      await db.update('settings', { _kThemeModeCol: 'system' }, where: 'id = 1');
    }
    if (!has(_kLanguageCodeCol)) {
      await db.execute("ALTER TABLE settings ADD COLUMN $_kLanguageCodeCol TEXT DEFAULT 'system';");
      await db.update('settings', { _kLanguageCodeCol: 'system' }, where: 'id = 1');
    }
  }

  Future<String> _getStringSetting(String col, String def) async {
    final db = await _dbHelper.database;
    final rows = await db.query('settings', columns: [col], where: 'id = 1', limit: 1);
    final v = (rows.isNotEmpty ? rows.first[col] : null) as String?;
    return (v == null || v.isEmpty) ? def : v;
  }

  // =================== MONEDA PRINCIPAL (YA EXISTÍA) ===================

  Future<String> getMainCurrency() async {
    final db = await _dbHelper.database;
    final result = await db.query('settings', columns: ['main_currency'], where: 'id = 1');
    if (result.isNotEmpty && result.first['main_currency'] != null) {
      return result.first['main_currency'] as String;
    } else {
      await setMainCurrency('USD'); // 👈 antes estaba 'DOP'
      return 'USD';
    }
  }

  Future<void> setMainCurrency(String newCurrency) async {
    final db = await _dbHelper.database;
    await db.update('settings', {'main_currency': newCurrency}, where: 'id = 1');
  }

  // =================== PRIMER DÍA DE SEMANA (YA TENÍAMOS) ===================

  static const String _kFirstWeekdayCol = 'first_day_of_week'; // 'monday' | 'sunday'

  Future<void> _ensureFirstWeekdayColumn() async {
    final db = await _dbHelper.database;
    final info = await db.rawQuery("PRAGMA table_info(settings);");
    final exists = info.any((c) => (c['name'] as String?) == _kFirstWeekdayCol);
    if (exists) return;
    await db.execute("ALTER TABLE settings ADD COLUMN $_kFirstWeekdayCol TEXT DEFAULT 'monday';");
    await db.update('settings', { _kFirstWeekdayCol: 'monday' }, where: 'id = 1');
  }

  // utils/settings_helper.dart
  Future<String> getFirstWeekday() async {
    await _ensureFirstWeekdayColumn();
    final db = await _dbHelper.database;
    final result = await db.query('settings', columns: [_kFirstWeekdayCol], where: 'id = 1', limit: 1);
    final raw = (result.isNotEmpty ? result.first[_kFirstWeekdayCol] : null) as String?;
    final v = (raw ?? 'monday').toLowerCase().trim();
    return (v == 'sunday') ? 'sunday' : 'monday';
  }

  Future<void> setFirstWeekday(String value) async {
    final v = value.toLowerCase().trim() == 'sunday' ? 'sunday' : 'monday';
    await _ensureFirstWeekdayColumn();
    final db = await _dbHelper.database;
    await db.update('settings', { _kFirstWeekdayCol: v }, where: 'id = 1');
  }

}
