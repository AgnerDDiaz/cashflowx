import 'package:cashflowx/screen/scheduled_transactions_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:cashflowx/utils/settings_helper.dart';
import 'package:cashflowx/screen/select_currency_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _firstDay = 'monday'; // 'monday' | 'sunday'
  String _mainCurrency = 'DOP';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final s = SettingsHelper();
    final fd = await s.getFirstWeekday();
    final mc = await s.getMainCurrency();
    if (!mounted) return;
    setState(() {
      _firstDay = (fd == 'sunday') ? 'sunday' : 'monday';
      _mainCurrency = mc;
    });
  }

  // Pequeño helper: si la key no existe, usa fallback
  String trOr(String key, String fallback) {
    final v = key.tr();
    return v == key ? fallback : v;
  }

  String _weekdayLabel(String v) {
    return v == 'sunday'
        ? trOr('sunday', 'Sunday')
        : trOr('monday', 'Monday');
  }

  Future<void> _openFirstDaySheet() async {
    String temp = _firstDay;

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      trOr('first_day_of_week', 'First day of week'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    value: 'monday',
                    groupValue: temp,
                    onChanged: (v) => setModalState(() => temp = v ?? 'monday'),
                    title: Text(_weekdayLabel('monday')),
                  ),
                  RadioListTile<String>(
                    value: 'sunday',
                    groupValue: temp,
                    onChanged: (v) => setModalState(() => temp = v ?? 'monday'),
                    title: Text(_weekdayLabel('sunday')),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(trOr('cancel', 'Cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, temp),
                            child: Text(trOr('save', 'Save')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (result != null && result != _firstDay) {
      await SettingsHelper().setFirstWeekday(result);
      if (!mounted) return;
      setState(() => _firstDay = result);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${trOr('settings_updated', 'Settings updated')} · ${_weekdayLabel(_firstDay)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(
        title: Text(trOr('settings', 'Settings'), style: titleStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Moneda principal
          ListTile(
            leading: const Icon(Icons.monetization_on),
            title: Text(trOr('choose_main_currency', 'Choose main currency')),
            subtitle: Text(_mainCurrency, style: bodyStyle),
            onTap: () async {
              final selected = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SelectCurrencyScreen()),
              );
              if (selected != null && selected is String) {
                await SettingsHelper().setMainCurrency(selected);
                if (!mounted) return;
                setState(() => _mainCurrency = selected);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('main_currency_updated_to'.tr(args: [selected]))),
                );
              }
            },
          ),
          const Divider(height: 1),

          // Primer día de la semana (NUEVO)
          ListTile(
            leading: const Icon(Icons.view_week),
            title: Text(trOr('first_day_of_week', 'First day of week')),
            subtitle: Text(_weekdayLabel(_firstDay), style: bodyStyle),
            onTap: _openFirstDaySheet,
          ),
          const Divider(height: 1),

          // Placeholders (botones listos para conectar)
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(trOr('manage_accounts', 'Manage accounts')),
            onTap: () {
              // TODO: navegar al gestor de cuentas
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(trOr('manage_categories', 'Manage categories')),
            onTap: () {
              // TODO: navegar al gestor de categorías
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.repeat),
            title: Text(trOr('scheduled_transactions', 'Scheduled transactions')),
            subtitle: Text(trOr('manage_scheduled_transactions', 'Manage scheduled transactions')),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduledTransactionsScreen()),
              );
            },
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: Text(trOr('budget_settings', 'Budget settings')),
            onTap: () {
              // TODO: ajustes de presupuesto
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(trOr('appearance', 'Appearance')),
            subtitle: Text(trOr('system_default', 'System default')),
            onTap: () {
              // TODO: claro / oscuro / sistema
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(trOr('change_language', 'Change language')),
            onTap: () {
              // TODO: seleccionar idioma
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(trOr('notifications', 'Notifications')),
            onTap: () {
              // TODO: configuración de notificaciones
            },
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
