import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/currency_service.dart';
import '../utils/database_helper.dart';
import '../utils/settings_helper.dart';

class SearchCurrencyFromApiScreen extends StatefulWidget {
  const SearchCurrencyFromApiScreen({Key? key}) : super(key: key);

  @override
  State<SearchCurrencyFromApiScreen> createState() => _SearchCurrencyFromApiScreenState();
}

class _SearchCurrencyFromApiScreenState extends State<SearchCurrencyFromApiScreen> {
  final CurrencyService _currencyService = CurrencyService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, String>> allCurrencies = [];
  String searchQuery = '';
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    try {
      final currencies = await _currencyService.getSupportedCurrencies();
      setState(() {
        allCurrencies = currencies;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading currencies: $e');
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _handleCurrencySelection(Map<String, String> currency) async {
    final code = currency['code']!;
    final name = currency['name'] ?? '';
    final mainCurrency = await SettingsHelper().getMainCurrency();

    final db = await _dbHelper.database;

    // Guardar nombre si no existe aún
    await db.insert('currency_names', {
      'code': code,
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Asegurar tasa de cambio base <-> mainCurrency
    try {
      await CurrencyService().ensureExchangeRateExists(
        baseCurrency: code,
        targetCurrency: mainCurrency,
        context: context,
      );
    } catch (e) {
      print('❌ Error al guardar tasa de cambio: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('error_saving_currency_exchange'.tr()),
      ));
      return;
    }

    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = allCurrencies.where((currency) {
      final code = (currency['code'] ?? '').toLowerCase();
      final name = (currency['name'] ?? '').toLowerCase();
      return code.contains(searchQuery.toLowerCase()) || name.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('add_new_currency'.tr(), style: Theme.of(context).textTheme.titleLarge),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
          ? Center(child: Text('error_loading_currencies'.tr()))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'search_currency'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredCurrencies.isEmpty
                ? Center(child: Text('no_currencies_found'.tr()))
                : ListView.builder(
              itemCount: filteredCurrencies.length,
              itemBuilder: (context, index) {
                final currency = filteredCurrencies[index];
                return ListTile(
                  title: Text("${currency['code']} - ${currency['name']}"),
                  onTap: () => _handleCurrencySelection(currency),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
