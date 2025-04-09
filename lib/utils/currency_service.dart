import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'database_helper.dart'; // Para guardar el nuevo tipo de cambio si hace falta

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  final String _apiKey = 'ee448aaece0efef7f07bf7c5'; // TODO: mover a variables seguras o archivo aparte
  final String _apiUrl = 'https://v6.exchangerate-api.com/v6';

  /// Obtener todas las monedas disponibles de la API
  Future<List<Map<String, String>>> getSupportedCurrencies() async {
    final url = Uri.parse('$_apiUrl/$_apiKey/codes');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] == 'success') {
          List supportedCodes = data['supported_codes'];
          return supportedCodes.map<Map<String, String>>((item) {
            return {
              'code': item[0],
              'name': item[1],
            };
          }).toList();
        } else {
          throw Exception('API error: ${data['error-type']}');
        }
      } else {
        throw Exception('Connection error: Status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timeout. Please try again.');
    } catch (e) {
      throw Exception('Failed to load currencies: $e');
    }
  }

  /// Asegura que exista una tasa de cambio entre dos monedas.
  /// Si no existe, la crea usando la API.
  Future<void> ensureExchangeRateExists({
    required String baseCurrency,
    required String targetCurrency,
    required dynamic context, // Para manejar errores visuales si quieres usarlo
  }) async {
    final dbHelper = DatabaseHelper();

    // 1. Verificar si ya existe en la base de datos
    final db = await dbHelper.database;
    final existing = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND target_currency = ?',
      whereArgs: [baseCurrency, targetCurrency],
    );

    if (existing.isNotEmpty) {
      // Ya existe, no hacer nada
      return;
    }

    try {
      final url = Uri.parse('$_apiUrl/$_apiKey/pair/$baseCurrency/$targetCurrency');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['result'] == 'success') {
          final rate = data['conversion_rate'];

          // 3. Guardarlo en la base de datos
          await db.insert('exchange_rates', {
            'base_currency': baseCurrency,
            'target_currency': targetCurrency,
            'rate': rate,
            'last_updated': DateTime.now().toIso8601String(),
          });
        } else {
          throw Exception('API error: ${data['error-type']}');
        }
      } else {
        throw Exception('Connection error: Status ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timeout. Please try again.');
    } catch (e) {
      throw Exception('Failed to ensure exchange rate exists: $e');
    }
  }
}
