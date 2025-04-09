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
  List<String> allCurrencies = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    final currencies = await _dbHelper.getAllCurrencies();
    setState(() {
      allCurrencies = currencies;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = allCurrencies.where((currency) {
      return currency.toLowerCase().contains(searchQuery.toLowerCase());
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
                return ListTile(
                  title: Text(currency),
                  onTap: () {
                    Navigator.pop(context, currency);
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
