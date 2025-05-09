import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/database_helper.dart';
import 'search_currency_from_api_screen.dart';

class SelectCurrencyScreen extends StatefulWidget {
  const SelectCurrencyScreen({Key? key}) : super(key: key);

  @override
  State<SelectCurrencyScreen> createState() => _SelectCurrencyScreenState();
}

class _SelectCurrencyScreenState extends State<SelectCurrencyScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> allCurrencies = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT base_currency AS code,
             (SELECT name FROM currency_names WHERE code = base_currency LIMIT 1) AS name
      FROM exchange_rates
      UNION
      SELECT DISTINCT target_currency AS code,
             (SELECT name FROM currency_names WHERE code = target_currency LIMIT 1) AS name
      FROM exchange_rates
    ''');

    setState(() {
      allCurrencies = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = allCurrencies.where((currency) {
      final code = (currency['code'] ?? '').toLowerCase();
      final name = (currency['name'] ?? '').toLowerCase();
      final combined = '$code - $name';
      return combined.contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('select_currency'.tr(), style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Column(
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
                final code = currency['code'] ?? '';
                final name = currency['name'] ?? '';
                return ListTile(
                  title: Text('$code - $name'),
                  onTap: () {
                    Navigator.pop(context, code);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                final newCurrency = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchCurrencyFromApiScreen()),
                );
                if (newCurrency != null && newCurrency is String) {
                  await _loadCurrencies(); // Recargar después de agregar
                  Navigator.pop(context, newCurrency);
                }
              },
              icon: const Icon(Icons.add),
              label: Text('add_new_currency'.tr()),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          )
        ],
      ),
    );
  }
}
