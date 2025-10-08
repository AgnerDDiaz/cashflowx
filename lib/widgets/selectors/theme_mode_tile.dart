import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ThemeModeTile extends StatelessWidget {
  final ThemeMode initialMode;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeTile({
    super.key,
    required this.initialMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = _trOr('appearance', 'Appearance');
    final subtitle = _modeLabel(initialMode);

    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => _openSheet(context),
    );
  }

  void _openSheet(BuildContext context) {
    final options = <ThemeMode>[ThemeMode.system, ThemeMode.light, ThemeMode.dark];

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
                Text(_trOr('appearance', 'Appearance'), style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(width: 24),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: options.map((m) {
                  return ListTile(
                    title: Text(_modeLabel(m)),
                    onTap: () {
                      onChanged(m);
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

  static String _modeLabel(ThemeMode m) {
    switch (m) {
      case ThemeMode.light: return _trOr('theme.light', 'Light');
      case ThemeMode.dark : return _trOr('theme.dark',  'Dark');
      case ThemeMode.system:
      default            : return _trOr('theme.system','System default');
    }
  }

  static String _trOr(String key, String fb) {
    final t = key.tr();
    return t == key ? fb : t;
  }
}
