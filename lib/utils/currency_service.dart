import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;

  CurrencyService._internal();

  final String _apiKey = 'ee448aaece0efef7f07bf7c5'; // Reemplaza con tu API Key
  final String _apiUrl = 'https://v6.exchangerate-api.com/v6';

  /// Obtener todas las monedas disponibles de la API
  Future<List<Map<String, String>>> getSupportedCurrencies() async {
    final url = Uri.parse('$_apiUrl/$_apiKey/codes');

    final response = await http.get(url);

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
        throw Exception('Error en la respuesta de la API: ${data['error-type']}');
      }
    } else {
      throw Exception('Error de conexión al cargar las monedas');
    }
  }
}
