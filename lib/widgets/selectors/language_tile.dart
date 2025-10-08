import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class LanguageTile extends StatelessWidget {
  final String initialCode;              // 'system' | 'en' | 'es' ...
  final ValueChanged<String> onChanged;  // devuelve el code elegido

  const LanguageTile({
    super.key,
    required this.initialCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = _trOr('change_language', 'Change language');
    final subtitle = _codeToLabel(initialCode);

    return ListTile(
      leading: const Icon(Icons.language_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => _openSheet(context),
    );
  }

  void _openSheet(BuildContext context) {
    // Toma los locales soportados de EasyLocalization
    final supported = context.supportedLocales;
    final entries = <String>['system', ...supported.map(_toCode)];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_trOr('change_language', 'Change language'), style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(width: 24),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: entries.map((code) {
                  return ListTile(
                    title: Text(_codeToLabel(code)),
                    onTap: () {
                      onChanged(code);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _toCode(Locale l) =>
      (l.countryCode == null || l.countryCode!.isEmpty)
          ? l.languageCode
          : '${l.languageCode}-${l.countryCode}';

  static String _codeToLabel(String code) {
    if (code == 'system') return _trOr('language.system', 'System default');
    // Mapa básico para nombres bonitos (ajústalo si tienes más idiomas)
    switch (code) {
      case 'es': return 'Español';
      case 'en': return 'English';
      default  : return code;
    }
  }

  static String _trOr(String key, String fb) {
    final t = key.tr();
    return t == key ? fb : t;
  }
}
