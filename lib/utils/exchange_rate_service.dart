import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cashflowx/utils/database_helper.dart';
import 'package:cashflowx/utils/settings_helper.dart';

class ExchangeRateService {
  static final ExchangeRateService _instance = ExchangeRateService._internal();
  factory ExchangeRateService() => _instance;

  ExchangeRateService._internal();

  final String _apiKey = 'ee448aaece0efef7f07bf7c5';
  final String _apiUrl = 'https://v6.exchangerate-api.com/v6/';
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// ✅ Obtener tasa de cambio, usando primero la base de datos local
  Future<double> getExchangeRate(BuildContext context, String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return 1.0;

    final now = DateTime.now();
    final result = await _dbHelper.getExchangeRateDetails(fromCurrency, toCurrency);

    if (result != null) {
      final lastUpdated = DateTime.parse(result['last_updated']);
      final difference = now.difference(lastUpdated).inDays;

      if (difference <= 90) {
        return result['rate'] as double;
      } else {
        try {
          final freshRate = await _fetchExchangeRateFromAPI(fromCurrency, toCurrency);
          await _dbHelper.saveOrUpdateExchangeRate(fromCurrency, toCurrency, freshRate);
          return freshRate;
        } catch (e) {
          return await _askUserToAddRateManually(context, fromCurrency, toCurrency, oldRate: result['rate']);
        }
      }
    } else {
      try {
        final freshRate = await _fetchExchangeRateFromAPI(fromCurrency, toCurrency);
        await _dbHelper.saveOrUpdateExchangeRate(fromCurrency, toCurrency, freshRate);
        return freshRate;
      } catch (e) {
        return await _askUserToAddRateManually(context, fromCurrency, toCurrency);
      }
    }
  }

  /// ✅ Convertir monto automáticamente a la moneda principal del usuario
  Future<double> convertAmount(BuildContext context, double amount, String fromCurrency) async {
    final mainCurrency = await SettingsHelper().getMainCurrency();
    final rate = await getExchangeRate(context, fromCurrency, mainCurrency);
    return amount * rate;
  }

  /// ✅ NUEVO: Conversión solo local SIN pedir a la API (usa solo base de datos)
  static Future<double> localConvert(double amount, String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return amount;

    final db = DatabaseHelper();

    // Buscar tasa directa
    final directRateDetail = await db.getExchangeRateDetails(fromCurrency, toCurrency);
    if (directRateDetail != null && directRateDetail['rate'] != null) {
      return amount * (directRateDetail['rate'] as double);
    }

    // Buscar tasa inversa
    final inverseRateDetail = await db.getExchangeRateDetails(toCurrency, fromCurrency);
    if (inverseRateDetail != null && inverseRateDetail['rate'] != null) {
      return amount / (inverseRateDetail['rate'] as double);
    }

    // No se encontró ninguna tasa
    print('⚠️ No se encontró tasa de cambio entre $fromCurrency y $toCurrency. Retornando mismo monto.');
    return amount;
  }


  /// ✅ Consultar la API para tasa de cambio
  Future<double> _fetchExchangeRateFromAPI(String fromCurrency, String toCurrency) async {
    final response = await http.get(Uri.parse('$_apiUrl$_apiKey/latest/$fromCurrency'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['result'] == 'success') {
        final rates = data['conversion_rates'];
        if (rates.containsKey(toCurrency)) {
          return (rates[toCurrency] as num).toDouble();
        } else {
          throw Exception('No se encontró tasa hacia $toCurrency');
        }
      } else {
        throw Exception('Error al obtener tasa de cambio: ${data['error-type']}');
      }
    } else {
      throw Exception('Error de conexión a la API de tipo de cambio');
    }
  }

  /// ✅ Preguntar al usuario para agregar tasa manual
  Future<double> _askUserToAddRateManually(BuildContext context, String fromCurrency, String toCurrency, {double? oldRate}) async {
    double manualRate = oldRate ?? 1.0;

    await showDialog(
      context: context,
      builder: (context) {
        final rateController = TextEditingController(text: manualRate.toString());

        return AlertDialog(
          title: const Text('Agregar tasa de cambio manualmente'),
          content: TextField(
            controller: rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '¿Cuánto equivale 1 $fromCurrency a $toCurrency?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final inputRate = double.tryParse(rateController.text);
                if (inputRate != null && inputRate > 0) {
                  await _dbHelper.saveOrUpdateExchangeRate(fromCurrency, toCurrency, inputRate);
                  Navigator.pop(context);
                  manualRate = inputRate;
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
