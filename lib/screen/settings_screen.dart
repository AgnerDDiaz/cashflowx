import 'package:cashflowx/screen/scheduled_transactions_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:cashflowx/utils/settings_helper.dart';
import 'package:cashflowx/screen/select_currency_screen.dart';

// Tile estándar para “Primer día de la semana”
import '../widgets/selectors/week_start_selector.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _firstDay = 'monday'; // 'monday' | 'sunday'
  String _mainCurrency = 'DOP';

  // Idioma/tema
  String _languageCode = 'system';       // 'system' | 'en' | 'es' | ...
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadLang();
    _loadTheme();
  }

  Future<void> _loadLang() async {
    _languageCode = await SettingsHelper().getLanguageCode();
    if (mounted) setState(() {});
  }

  Future<void> _loadTheme() async {
    _themeMode = await SettingsHelper().getThemeMode();
    if (mounted) setState(() {});
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

  // Helper: si la key no existe, usa fallback
  String trOr(String key, String fallback) {
    final v = key.tr();
    return v == key ? fallback : v;
  }

  String _weekdayLabel(String v) =>
      v == 'sunday' ? trOr('sunday', 'Sunday') : trOr('monday', 'Monday');

  // ======== THEME ========

  String _themeLabel(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return trOr('theme.light', 'Light');
      case ThemeMode.dark:
        return trOr('theme.dark', 'Dark');
      case ThemeMode.system:
      default:
        return trOr('theme.system', 'System default');
    }
  }

  Future<void> _openThemeSheet() async {
    final options = <ThemeMode>[
      ThemeMode.system,
      ThemeMode.light,
      ThemeMode.dark,
    ];

    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(trOr('appearance', 'Appearance'),
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: options.map((m) {
                    return ListTile(
                      title: Text(_themeLabel(m)),
                      onTap: () => Navigator.pop(ctx, m),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != _themeMode) {
      await SettingsHelper().setThemeMode(picked); // persiste + notifica
      if (!mounted) return;
      setState(() => _themeMode = picked);
    }
  }

  // ======== LANGUAGE ========

  String _languageLabel(String code) {
    if (code == 'system') return trOr('language.system', 'System default');
    // Mapa simple (ajústalo si agregas más idiomas)
    switch (code) {
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }

  Future<void> _openLanguageSheet() async {
    final supported = context.supportedLocales;
    final entries = <String>['system', ...supported.map(_toCode)];

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(trOr('change_language', 'Change language'),
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: entries.map((code) {
                    return ListTile(
                      title: Text(_languageLabel(code)),
                      onTap: () => Navigator.pop(ctx, code),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != _languageCode) {
      await SettingsHelper().setLanguageCode(picked);
      if (!mounted) return;

      // Aplica el idioma en vivo
      if (picked == 'system') {
        final dev = context.deviceLocale;
        await context.setLocale(Locale(dev.languageCode, dev.countryCode));
      } else {
        final parts = picked.split('-');
        final loc =
        parts.length == 2 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
        await context.setLocale(loc);
      }

      setState(() => _languageCode = picked);
    }
  }

  String _toCode(Locale l) =>
      (l.countryCode == null || l.countryCode!.isEmpty)
          ? l.languageCode
          : '${l.languageCode}-${l.countryCode}';

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
                  SnackBar(
                    content: Text(
                      'main_currency_updated_to'.tr(args: [selected]),
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),

          // --- Primer día de la semana (tile estándar) ---
          WeekStartTile(
            initialValue: _firstDay, // 'monday' | 'sunday'
            onChanged: (v) async {
              await SettingsHelper().setFirstWeekday(v);
              if (!mounted) return;
              setState(() => _firstDay = v);
            },
          ),
          const Divider(height: 1),

          // --- Apariencia: mantiene el botón, abre selector ---
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(trOr('appearance', 'Appearance')),
            subtitle: Text(_themeLabel(_themeMode)),
            onTap: _openThemeSheet,
          ),
          const Divider(height: 1),

          // --- Idioma: mantiene el botón, abre selector ---
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(trOr('change_language', 'Change language')),
            subtitle: Text(_languageLabel(_languageCode)),
            onTap: _openLanguageSheet,
          ),
          const Divider(height: 1),

          // --- Resto de opciones existentes ---
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
