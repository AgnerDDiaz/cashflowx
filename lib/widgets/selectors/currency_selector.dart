import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class CurrencySelector extends StatelessWidget {
  final List<String> currencies;
  final String selectedCurrency;
  final Function(String) onChanged;
  final VoidCallback onOtherSelected;

  const CurrencySelector({
    Key? key,
    required this.currencies,
    required this.selectedCurrency,
    required this.onChanged,
    required this.onOtherSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<String>> currencyItems = currencies
        .map((currency) => DropdownMenuItem<String>(
      value: currency,
      child: Text(currency),
    ))
        .toList();

    currencyItems.add(
      DropdownMenuItem<String>(
        value: 'other',
        child: Text('others'.tr()), // 👈 Ahora usando easy_localization
      ),
    );

    return DropdownButtonFormField<String>(
      value: currencies.contains(selectedCurrency) ? selectedCurrency : null,
      items: currencyItems,
      decoration: InputDecoration(
        labelText: 'currency'.tr(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: (value) {
        if (value == 'other') {
          onOtherSelected();
        } else if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
