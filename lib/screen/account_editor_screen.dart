import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/account.dart';
import '../repositories/accounts_repository.dart';
import '../widgets/selectors/currency_selector.dart';
import 'search_currency_from_api_screen.dart';

class AccountEditorScreen extends StatefulWidget {
  final Account? initial;

  const AccountEditorScreen({super.key, this.initial});

  @override
  State<AccountEditorScreen> createState() => _AccountEditorScreenState();
}

class _AccountEditorScreenState extends State<AccountEditorScreen> {
  final _repo = AccountsRepository();
  final _form = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _balanceCtrl;       // balance
  late TextEditingController _creditLimitCtrl;   // max_credit
  late TextEditingController _statementDayCtrl;  // cutoff_date (día 1..28 como texto)

  // Tipos: 'normal' | 'credit' | 'saving' | 'debt'
  String _type = 'normal';
  String _currency = 'DOP';
  bool _includeInTotal = true;

  // Grupo actual (si viene nulo, el repo creará/forzará "General")
  int? _groupId;

  static const List<String> _quickCurrencies = ['DOP', 'USD', 'EUR', 'GBP', 'MXN', 'CAD'];

  @override
  void initState() {
    super.initState();
    final a = widget.initial;

    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _balanceCtrl = TextEditingController(text: (a?.balance ?? 0.0).toStringAsFixed(2));
    _creditLimitCtrl = TextEditingController(text: a?.maxCredit?.toString() ?? '');
    _statementDayCtrl = TextEditingController(text: a?.cutoffDate ?? '');

    _type = a?.type ?? 'normal';
    _currency = a?.currency ?? 'DOP';
    _includeInTotal = (a?.includeInBalance ?? 1) == 1;
    _groupId = a?.groupId; // puede quedar null; el repo lo resolverá con "General"
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _creditLimitCtrl.dispose();
    _statementDayCtrl.dispose();
    super.dispose();
  }

  double _parseDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return 0.0;
    return double.tryParse(t.replaceAll(',', '.')) ?? 0.0;
  }

  int? _parseInt(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _openCurrencyPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('select_currency'.tr(), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                CurrencySelector(
                  currencies: _quickCurrencies.map((c) => {"code": c, "name": ""}).toList(),
                  initialSelectedCode: _currency,
                  onSelect: (code) {
                    setState(() => _currency = code);
                  },
                ),

              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    // Mapear tipo -> balance_mode
    String balanceMode;
    switch (_type) {
      case 'credit':
        balanceMode = 'credit';
        break;
      case 'saving':
        balanceMode = 'default';
        break;
      case 'debt':
        balanceMode = 'credit';
        break;
      case 'normal':
      default:
        balanceMode = 'default';
        break;
    }

    // Solo para tarjetas
    String? cutoffText;
    double? creditLimit;
    if (_type == 'credit') {
      final day = _parseInt(_statementDayCtrl.text);
      if (day != null && (day < 1 || day > 28)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('statement_day_range'.tr(args: ['1', '28']))),
        );
        return;
      }
      cutoffText = day?.toString();

      final lim = _creditLimitCtrl.text.trim();
      creditLimit = lim.isEmpty ? null : _parseDouble(lim);
    }

    final account = Account(
      id: widget.initial?.id,
      name: _nameCtrl.text.trim(),
      type: _type,
      groupId: _groupId, // puede ser null; el repo asegurará "General"
      balance: _parseDouble(_balanceCtrl.text),
      currency: _currency,
      balanceMode: balanceMode,
      dueDate: null,                 // no editable aquí (puedes añadirlo luego)
      cutoffDate: cutoffText,        // solo crédito
      maxCredit: creditLimit,        // solo crédito
      visible: 1,
      includeInBalance: _includeInTotal ? 1 : 0,
    );

    if (account.id == null) {
      await _repo.insert(account);
    } else {
      await _repo.update(account);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'edit_account'.tr() : 'new_account'.tr()),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Nombre
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: 'name'.tr()),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'required'.tr() : null,
              ),
              const SizedBox(height: 12),

              // Tipo
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(labelText: 'type'.tr()),
                items: [
                  DropdownMenuItem(value: 'normal', child: Text('normal_account'.tr())),
                  DropdownMenuItem(value: 'credit', child: Text('credit_card'.tr())),
                  DropdownMenuItem(value: 'saving', child: Text('savings'.tr())),
                  DropdownMenuItem(value: 'debt', child: Text('debt'.tr())),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'normal'),
              ),

              const SizedBox(height: 12),

              // Moneda
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('currency'.tr()),
                subtitle: Text(_currency),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openCurrencyPicker,
              ),

              const SizedBox(height: 8),

              // Balance
              TextFormField(
                controller: _balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'initial_balance'.tr()),
              ),

              const SizedBox(height: 12),

              // Incluir en balance total
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _includeInTotal,
                title: Text('include_in_total_balance'.tr()),
                onChanged: (v) => setState(() => _includeInTotal = v),
              ),

              // Solo para tarjetas de crédito
              if (_type == 'credit') ...[
                const Divider(height: 24),
                TextFormField(
                  controller: _creditLimitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'credit_limit_optional'.tr()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _statementDayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'statement_day_optional'.tr()),
                ),
              ],

              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text('save'.tr()),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
