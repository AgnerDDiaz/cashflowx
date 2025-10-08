import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../screen/select_currency_screen.dart';

class CurrencySelector extends StatefulWidget {
  /// Lista de monedas. Espera mapas con: { "code": "USD", "name": "United States Dollar" }
  final List<Map<String, dynamic>> currencies;
  final String? initialSelectedCode;
  final ValueChanged<String> onSelect;

  const CurrencySelector({
    Key? key,
    required this.currencies,
    required this.onSelect,
    this.initialSelectedCode,
  }) : super(key: key);

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  String? selectedCode;

  @override
  void initState() {
    super.initState();
    selectedCode = widget.initialSelectedCode;
  }

  @override
  Widget build(BuildContext context) {
    final label = selectedCode != null
        ? _displayNameFor(selectedCode!)
        : 'select_currency'.tr();

    return GestureDetector(
      onTap: _showCurrencyModal,
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
            Icon(Icons.arrow_drop_down,
                size: 24, color: Theme.of(context).iconTheme.color),
          ],
        ),
      ),
    );
  }

  String _displayNameFor(String code) {
    final m = widget.currencies
        .cast<Map<String, dynamic>?>()
        .firstWhere((c) => (c?['code'] ?? '') == code, orElse: () => null);
    if (m == null) return code; // fallback
    final name = (m['name'] ?? '').toString();
    return name.isEmpty ? code : '$code - $name';
  }

  void _showCurrencyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetCtx) {
        final textColor = Theme.of(sheetCtx).textTheme.titleLarge?.color;
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(sheetCtx).size.height * 0.6,
          child: Column(
            children: [
              // Header: título + "+"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('currency'.tr(),
                      style: Theme.of(sheetCtx).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: textColor, // mismo color que el texto (negro/blanco)
                    tooltip: 'add'.tr(),
                    onPressed: () async {
                      final result = await Navigator.push(
                        sheetCtx,
                        MaterialPageRoute(
                          builder: (_) => const SelectCurrencyScreen(),
                        ),
                      );
                      if (result is String && result.isNotEmpty) {
                        setState(() => selectedCode = result);
                        widget.onSelect(result);
                        Navigator.pop(sheetCtx); // cerrar el modal
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.currencies.length,
                  itemBuilder: (_, i) {
                    final c = widget.currencies[i];
                    final code = (c['code'] ?? '').toString();
                    final name = (c['name'] ?? '').toString();
                    final label = name.isEmpty ? code : '$code - $name';
                    return ListTile(
                      title: Text(label),
                      onTap: () {
                        setState(() => selectedCode = code);
                        widget.onSelect(code);
                        Navigator.pop(sheetCtx);
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
}
