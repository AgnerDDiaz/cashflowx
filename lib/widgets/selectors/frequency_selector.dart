import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class FrequencySelector extends StatefulWidget {
  final String? initialValue;             // 'weekly' | 'biweekly' | 'monthly' | 'quarterly' | 'semiannual' | 'annual'
  final ValueChanged<String> onSelect;

  const FrequencySelector({
    super.key,
    required this.onSelect,
    this.initialValue,
  });

  @override
  State<FrequencySelector> createState() => _FrequencySelectorState();
}

class _FrequencySelectorState extends State<FrequencySelector> {
  late String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final label = _value != null ? _labelFor(_value!, context) : tr('scheduled.frequency');
    return GestureDetector(
      onTap: _openSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Icon(Icons.arrow_drop_down, size: 24, color: Theme.of(context).iconTheme.color),
          ],
        ),
      ),
    );
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        final options = _options(ctx);
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tr('scheduled.frequency'), style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(width: 24), // sin '+'
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    return ListTile(
                      title: Text(opt['label'] as String),
                      onTap: () {
                        setState(() => _value = opt['value'] as String);
                        widget.onSelect(_value!);
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

  String _labelFor(String v, BuildContext ctx) =>
      _options(ctx).firstWhere((o) => o['value'] == v)['label'] as String;

  List<Map<String, String>> _options(BuildContext ctx) => [
    {'value': 'weekly',     'label': tr('scheduled.freq_weekly_short')},
    {'value': 'biweekly',   'label': tr('scheduled.freq_biweekly_short')},
    {'value': 'monthly',    'label': tr('scheduled.freq_monthly_short')},
    {'value': 'quarterly',  'label': tr('scheduled.freq_quarterly_short')},
    {'value': 'semiannual', 'label': tr('scheduled.freq_semiannual_short')},
    {'value': 'annual',     'label': tr('scheduled.freq_annual_short')},
  ];
}
