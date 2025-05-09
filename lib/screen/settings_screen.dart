import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cashflowx/utils/settings_helper.dart';
import 'package:cashflowx/screen/select_currency_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr(), style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.monetization_on),
            title: Text('choose_main_currency'.tr()),
            onTap: () async {
              final selected = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectCurrencyScreen()),
              );

              if (selected != null && selected is String) {
                await SettingsHelper().setMainCurrency(selected);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('main_currency_updated_to'.tr(args: [selected]))),
                );
              }
            },
          ),
          const Divider(height: 1),
          // Aquí puedes añadir más opciones fácilmente
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('change_language'.tr()),
            onTap: () {
              // lógica para cambiar idioma
            },
          ),
          const Divider(height: 1),
        ],
      ),

    );
  }
}
