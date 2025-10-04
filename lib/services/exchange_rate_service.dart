import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../utils/database_helper.dart';
import '../utils/settings_helper.dart';

class ExchangeRateService {
  static final ExchangeRateService _instance = ExchangeRateService._internal();
  factory ExchangeRateService() => _instance;
  ExchangeRateService._internal();

  // ⚠️ Mueve tu API key a un lugar seguro en producción.
  final String _apiKey = 'ee448aaece0efef7f07bf7c5';
  final String _apiUrl = 'https://v6.exchangerate-api.com/v6/';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Devuelve la tasa from->to aplicando política:
  /// 1) Usa local si es reciente (<= maxAgeDays).
  /// 2) Si no, intenta API y cachea.
  /// 3) Si falla, pide manual (si context != null), si no lanza error.
  Future<double> getExchangeRate(
      String fromCurrency,
      String toCurrency, {
        BuildContext? context,
        int maxAgeDays = 90,
      }) async {
    if (fromCurrency == toCurrency) return 1.0;

    final db = await _dbHelper.database;

    // 1) Local fresca
    final local = await _queryLocal(db, fromCurrency, toCurrency);
    if (local != null) {
      final last = DateTime.parse(local['last_updated'] as String);
      if (DateTime.now().difference(last).inDays <= maxAgeDays) {
        return (local['rate'] as num).toDouble();
      }
    }

    // 2) Intentar API
    try {
      final fresh = await _fetchFromAPI(fromCurrency, toCurrency);
      await _upsert(db, fromCurrency, toCurrency, fresh, DateTime.now());
      return fresh;
    } catch (_) {
      // 3) Manual si hay contexto; si no, intentar inversa local; si no, error
      if (context != null) {
        final manual = await _askUserToAddRateManually(context, fromCurrency, toCurrency);
        await _upsert(db, fromCurrency, toCurrency, manual, DateTime.now());
        await _logManual(db, fromCurrency, toCurrency, manual);
        return manual;
      }

      // Fallback: intentar inversa local (aunque esté vieja)
      final inverse = await _queryLocal(db, toCurrency, fromCurrency);
      if (inverse != null) {
        final invRate = (inverse['rate'] as num).toDouble();
        if (invRate > 0) return 1.0 / invRate;
      }

      throw StateError('No hay tasa disponible para $fromCurrency → $toCurrency.');
    }
  }

  /// Convierte un monto de [fromCurrency] a [toCurrency] usando la política de arriba.
  Future<double> convert(
      double amount,
      String fromCurrency,
      String toCurrency, {
        BuildContext? context,
        int maxAgeDays = 90,
      }) async {
    if (fromCurrency == toCurrency) return amount;
    final rate = await getExchangeRate(fromCurrency, toCurrency, context: context, maxAgeDays: maxAgeDays);
    return amount * rate;
  }

  /// Convierte un monto a la moneda principal del usuario.
  Future<double> convertToMainCurrency(
      double amount,
      String fromCurrency, {
        BuildContext? context,
        int maxAgeDays = 90,
      }) async {
    final mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';
    return await convert(amount, fromCurrency, mainCurrency, context: context, maxAgeDays: maxAgeDays);
  }

  /// Conversión local **sin** red ni prompts. Usa tabla `exchange_rates`.
  static Future<double> localConvert(double amount, String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return amount;
    final db = await DatabaseHelper().database;

    // directa
    final direct = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [fromCurrency, toCurrency],
      orderBy: 'last_updated DESC, id DESC',
      limit: 1,
    );
    if (direct.isNotEmpty) {
      final r = (direct.first['rate'] as num).toDouble();
      return amount * r;
    }

    // inversa
    final inverse = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [toCurrency, fromCurrency],
      orderBy: 'last_updated DESC, id DESC',
      limit: 1,
    );
    if (inverse.isNotEmpty) {
      final r = (inverse.first['rate'] as num).toDouble();
      if (r > 0) return amount / r;
    }

    // sin dato
    return amount;
  }

  // =========================
  // Internals
  // =========================

  Future<Map<String, Object?>?> _queryLocal(Database db, String from, String to) async {
    // directa
    final direct = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [from, to],
      orderBy: 'last_updated DESC, id DESC',
      limit: 1,
    );
    if (direct.isNotEmpty) return direct.first;

    // inversa (devolveremos convertida afuera si nos sirve)
    final inverse = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [to, from],
      orderBy: 'last_updated DESC, id DESC',
      limit: 1,
    );
    if (inverse.isNotEmpty) {
      final inv = inverse.first;
      final rate = (inv['rate'] as num).toDouble();
      if (rate > 0) {
        // Nota: devolvemos como si fuera directa (from->to)
        return {
          'rate': 1.0 / rate,
          'last_updated': inv['last_updated'],
          'id': inv['id'],
          'base_currency': from,
          'target_currency': to,
        };
      }
    }
    return null;
  }

  Future<void> _upsert(Database db, String from, String to, double rate, DateTime when) async {
    // Intentar update
    final updated = await db.update(
      'exchange_rates',
      {
        'rate': rate,
        'last_updated': when.toIso8601String().substring(0, 10),
      },
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [from, to],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    if (updated > 0) return;

    // Insert si no existía
    await db.insert('exchange_rates', {
      'base_currency': from,
      'target_currency': to,
      'rate': rate,
      'last_updated': when.toIso8601String().substring(0, 10),
    });
  }

  Future<void> _logManual(Database db, String from, String to, double rate) async {
    await db.insert('custom_exchange_rates_log', {
      'base_currency': from,
      'target_currency': to,
      'rate': rate,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<double> _fetchFromAPI(String fromCurrency, String toCurrency) async {
    final url = Uri.parse('$_apiUrl$_apiKey/latest/$fromCurrency');
    final resp = await http.get(url);

    if (resp.statusCode != 200) {
      throw Exception('Error HTTP ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body);
    if (body is! Map || body['result'] != 'success') {
      throw Exception('API error: ${body['error-type'] ?? 'unknown'}');
    }

    final rates = body['conversion_rates'] as Map<String, dynamic>?;
    if (rates == null || !rates.containsKey(toCurrency)) {
      throw Exception('No hay tasa hacia $toCurrency');
    }
    return (rates[toCurrency] as num).toDouble();
  }

  Future<double> _askUserToAddRateManually(
      BuildContext context,
      String fromCurrency,
      String toCurrency, {
        double? oldRate,
      }) async {
    double manualRate = oldRate ?? 1.0;

    await showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: manualRate.toString());
        return AlertDialog(
          title: const Text('Agregar tasa de cambio'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '¿Cuánto equivale 1 $fromCurrency en $toCurrency?',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(controller.text);
                if (v != null && v > 0) {
                  manualRate = v;
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    return manualRate;
  }
}
