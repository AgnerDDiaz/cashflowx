import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Opción de ajustes para elegir el primer día de la semana.
/// Mantiene el bottom sheet estandarizado, pero se ve como un ListTile.
/// Valor: 'monday' | 'sunday'
class WeekStartTile extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final IconData leadingIcon;

  const WeekStartTile({
    super.key,
    required this.onChanged,
    this.initialValue,
    this.leadingIcon = Icons.view_week, // ícono de la fila
  });

  @override
  State<WeekStartTile> createState() => _WeekStartTileState();

  /// Helper por si quieres obtener el label corto en otros lados.
  static String labelFromValue(BuildContext ctx, String v) {
    final loc = ctx.locale.toString();
    final baseMonday = DateTime(2024, 1, 1); // Monday
    final weekday = v == 'sunday' ? 7 : 1;   // map a DateTime.weekday
    final date = baseMonday.add(Duration(days: weekday - 1));
    return DateFormat('EEE', loc).format(date); // Mon/Sun o Lun/Dom
  }
}

class _WeekStartTileState extends State<WeekStartTile> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue ?? 'monday';
  }

  @override
  Widget build(BuildContext context) {
    final title = _trOr('first_day_of_week', 'First day of week');
    final subtitle = WeekStartTile.labelFromValue(context, _value);

    return ListTile(
      leading: Icon(widget.leadingIcon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: _openSheet,
    );
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        final options = const ['monday', 'sunday'];
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_trOr('first_day_of_week', 'First day of week'),
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final v = options[i];
                    return ListTile(
                      title: Text(WeekStartTile.labelFromValue(ctx, v)),
                      onTap: () {
                        setState(() => _value = v);
                        widget.onChanged(v);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _trOr(String key, String fallback) {
    final t = key.tr();
    return t == key ? fallback : t;
  }
}
