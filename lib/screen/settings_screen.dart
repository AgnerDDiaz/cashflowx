import 'package:flutter/material.dart';
import 'package:cashflowx/utils/settings_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  void _showChangeMainCurrencyDialog(BuildContext context) {
    final TextEditingController currencyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar Moneda Principal'),
          content: TextField(
            controller: currencyController,
            decoration: const InputDecoration(
              labelText: 'Nueva moneda principal (ej: DOP, USD, EUR)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newCurrency = currencyController.text.trim().toUpperCase();
                if (newCurrency.isNotEmpty) {
                  await SettingsHelper().setMainCurrency(newCurrency);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Moneda principal actualizada a $newCurrency')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuraciones'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.monetization_on),
          label: const Text('Cambiar Moneda Principal'),
          onPressed: () => _showChangeMainCurrencyDialog(context),
        ),
      ),
    );
  }
}
