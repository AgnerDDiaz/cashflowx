import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/currency_service.dart';
import '../utils/settings_helper.dart';

class SelectCurrencyScreen extends StatefulWidget {
  const SelectCurrencyScreen({Key? key}) : super(key: key);

  @override
  State<SelectCurrencyScreen> createState() => _SelectCurrencyScreenState();
}

class _SelectCurrencyScreenState extends State<SelectCurrencyScreen> {
  final CurrencyService _currencyService = CurrencyService();
  List<Map<String, String>> allCurrencies = [];
  bool loading = true;

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
        loading = false;
      });
    } catch (e) {
      print('Error loading currencies: $e');
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('select_currency'.tr()),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: allCurrencies.length,
        itemBuilder: (context, index) {
          final currency = allCurrencies[index];
          return ListTile(
            title: Text("${currency['code']} - ${currency['name']}", overflow: TextOverflow.ellipsis),
            onTap: () {
              Navigator.pop(context, currency['code']);
            },
          );
        },
      ),
    );
  }
}
