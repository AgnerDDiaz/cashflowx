import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/scheduled_transaction.dart';
import '../repositories/scheduled_transactions_repository.dart';
import '../services/transaction_service.dart';
import '../utils/database_helper.dart';
import '../utils/app_colors.dart';

// Selectores existentes en tu app
import '../widgets/selectors/account_selector.dart';
import '../widgets/selectors/category_selector.dart';
import '../widgets/selectors/currency_selector.dart';

class EditScheduledTransactionScreen extends StatefulWidget {
  final ScheduledTransaction? transaction; // null => crear

  const EditScheduledTransactionScreen({Key? key, this.transaction}) : super(key: key);

  @override
  State<EditScheduledTransactionScreen> createState() => _EditScheduledTransactionScreenState();
}

class _EditScheduledTransactionScreenState extends State<EditScheduledTransactionScreen> {
  final _repo = ScheduledTransactionsRepository();
  final _db = DatabaseHelper();
  final _txService = TransactionService();
  final _fmt = DateFormat('yyyy-MM-dd');

  // datos base para selectores
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _currencies = [];
  String _mainCurrency = 'DOP';

  // estado UI
  String _type = 'expense'; // expense | income | transfer
  DateTime _startDate = DateTime.now();
  int? _accountId;
  int? _linkedAccountId;
  int? _categoryId;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _currency = 'DOP';
  double? _previewInMain;

  String _frequency = 'monthly';
  bool _isActive = true;

  bool get _isEdit => widget.transaction != null;
  ScheduledTransactionFields? _originalComparable; // detectar cambios “estructurales”
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLoad();
    _amountCtrl.addListener(_recalcPreview);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_recalcPreview);
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    final db = await _db.database;

    _accounts = await db.query(
      'accounts',
      columns: ['id', 'name', 'currency', 'visible'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    _categories = await db.query(
      'categories',
      columns: ['id', 'name', 'type', 'parent_id'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    final set = <String>{'DOP','USD','EUR'};
    for (final a in _accounts) {
      final c = a['currency'] as String?;
      if (c != null && c.isNotEmpty) set.add(c);
    }
    _currencies = set.toList()..sort();
    if (_accounts.isNotEmpty) {
      _mainCurrency = (_accounts.first['currency'] as String?) ?? 'DOP';
    }

    if (_isEdit) {
      final s = widget.transaction!;
      _type = s.type;
      _accountId = s.accountId;
      _linkedAccountId = s.linkedAccountId;
      _categoryId = s.categoryId;
      _amountCtrl.text = s.amount.toStringAsFixed(2);
      _currency = s.currency;
      _startDate = DateTime.parse(s.startDate);
      _frequency = s.frequency;
      _noteCtrl.text = s.note ?? '';
      _isActive = s.isActive == 1;

      _originalComparable = ScheduledTransactionFields(
        type: _type,
        accountId: _accountId,
        linkedId: _linkedAccountId,
        categoryId: _categoryId,
        amount: s.amount,
        currency: _currency,
        frequency: _frequency,
        startIso: s.startDate,
      );
    } else {
      // >>> CAMBIO: NO auto-seleccionar cuenta; dejar “Select Account”
      _accountId = null;
      _linkedAccountId = null;
      _categoryId = null;
      _currency = _mainCurrency; // o deja 'DOP' si prefieres
    }

    _recalcPreview();
    setState(() => _loading = false);
  }

  // === helpers ===
  void _recalcPreview() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      setState(() => _previewInMain = null);
      return;
    }
    setState(() => _previewInMain = null); // integrar ExchangeRateService si deseas
  }

  DateTime _floorDate(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _advance(DateTime d, String freq) {
    DateTime addMonths(int n) {
      final year = d.year;
      final month = d.month + n;
      final lastDay = DateTime(year, month + 1, 0).day;
      final day = d.day > lastDay ? lastDay : d.day;
      return DateTime(year, month, day);
    }

    switch (freq.toLowerCase()) {
      case 'weekly': return d.add(const Duration(days: 7));
      case 'biweekly': return d.add(const Duration(days: 14));
      case 'monthly': return addMonths(1);
      case 'quarterly': return addMonths(3);
      case 'semiannual': return addMonths(6);
      case 'annual': return DateTime(d.year + 1, d.month, d.day);
      default: return addMonths(1);
    }
  }

  bool _structuralChangedAgainst(ScheduledTransactionFields other) {
    final current = ScheduledTransactionFields(
      type: _type,
      accountId: _accountId,
      linkedId: _linkedAccountId,
      categoryId: _categoryId,
      amount: double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0,
      currency: _currency,
      frequency: _frequency,
      startIso: _fmt.format(_startDate),
    );
    return current != other;
  }

  // === UI ===
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final title = _isEdit ? tr('scheduled.edit_title') : tr('scheduled.create_title');

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: tr('common.delete'),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _typeTabs(),
            const SizedBox(height: 16),

            // “Título” (se guarda como note)
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: tr('scheduled.title_field'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),

            const SizedBox(height: 16),

            _datePicker(),
            const SizedBox(height: 16),

            // Selector de cuenta (sin selección inicial en crear)
            AccountSelector(
              accounts: _accounts,
              initialSelectedId: _accountId,
              onSelect: (id) {
                setState(() {
                  _accountId = id;
                  final m = _accounts.firstWhere((a) => a['id'] == id, orElse: () => {});
                  if (m.isNotEmpty) _currency = (m['currency'] as String?) ?? _currency;
                  if (_type == 'transfer' && _linkedAccountId == _accountId) {
                    _linkedAccountId = null;
                  }
                });
              },

            ),

            if (_type == 'transfer')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: AccountSelector(
                  accounts: _accounts.where((a) => a['id'] != _accountId).toList(),
                  initialSelectedId: _linkedAccountId,
                  onSelect: (id) => setState(() => _linkedAccountId = id),
                ),
              ),

            if (_type != 'transfer')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: CategorySelector(
                  categories: _categories,
                  transactionType: _type,
                  initialSelectedId: _categoryId,
                  onSelect: (id) => setState(() => _categoryId = id),
                ),
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+([.]\d{0,2})?'))],
                    decoration: InputDecoration(
                      labelText: tr('scheduled.amount'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: CurrencySelector(
                    currencies: _currencies,
                    selectedCurrency: _currency,
                    onChanged: (c) => setState(() => _currency = c),
                    onOtherSelected: () {},
                  ),
                ),
              ],
            ),
            if (_previewInMain != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text('≈ ${_previewInMain!.toStringAsFixed(2)} $_mainCurrency',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ),

            const SizedBox(height: 16),

            // Frecuencia localizable
            DropdownButtonFormField<String>(
              value: _frequency,
              items: [
                DropdownMenuItem(value: 'weekly', child: Text(tr('scheduled.freq_weekly_short'))),
                DropdownMenuItem(value: 'biweekly', child: Text(tr('scheduled.freq_biweekly_short'))),
                DropdownMenuItem(value: 'monthly', child: Text(tr('scheduled.freq_monthly_short'))),
                DropdownMenuItem(value: 'quarterly', child: Text(tr('scheduled.freq_quarterly_short'))),
                DropdownMenuItem(value: 'semiannual', child: Text(tr('scheduled.freq_semiannual_short'))),
                DropdownMenuItem(value: 'annual', child: Text(tr('scheduled.freq_annual_short'))),
              ],
              onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
              decoration: InputDecoration(
                labelText: tr('scheduled.frequency'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              isExpanded: true,
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('scheduled.active'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
              ],
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'income'
                      ? AppColors.ingresoColor
                      : _type == 'expense'
                      ? AppColors.gastoColor
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _save,
                child: Text(_isEdit ? tr('common.save_changes') : tr('common.save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeTabs() {
    final items = [
      {'label': tr('scheduled.tab_expenses'), 'value': 'expense', 'color': AppColors.gastoColor},
      {'label': tr('scheduled.tab_income'), 'value': 'income', 'color': AppColors.ingresoColor},
      {'label': tr('scheduled.tab_transfer'), 'value': 'transfer', 'color': Colors.grey},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((it) {
        final selected = _type == it['value'];
        return GestureDetector(
          onTap: () => setState(() {
            _type = it['value'] as String;
            if (_type == 'transfer') {
              _categoryId = null;
            } else {
              _linkedAccountId = null;
            }
          }),
          child: Column(
            children: [
              Text(
                it['label'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? it['color'] as Color : null,
                ),
              ),
              if (selected) Container(height: 3, width: 60, color: it['color'] as Color),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime.now(), // no pasado
          lastDate: DateTime(2100),
          helpText: tr('scheduled.pick_date'),
        );
        if (picked != null) setState(() => _startDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('d MMM y', context.locale.toString()).format(_startDate),
                style: Theme.of(context).textTheme.bodyLarge),
            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).iconTheme.color),
          ],
        ),
      ),
    );
  }

  // === acciones ===
  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
    if (_accountId == null) return _toast(tr('scheduled.err_select_account'));
    if (amount <= 0) return _toast(tr('scheduled.err_amount'));
    if (_type == 'transfer') {
      if (_linkedAccountId == null || _linkedAccountId == _accountId) {
        return _toast(tr('scheduled.err_select_dest'));
      }
    } else {
      if (_categoryId == null) return _toast(tr('scheduled.err_select_category'));
    }

    final today = _floorDate(DateTime.now());
    final start = _floorDate(_startDate);
    if (start.isBefore(today)) {
      setState(() => _startDate = today);
      return _toast(tr('scheduled.err_start_past'));
    }

    final startIso = _fmt.format(_startDate);
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    if (_isEdit) {
      final changed = _structuralChangedAgainst(_originalComparable!);

      if (changed) {
        // desactivar antigua
        await _repo.toggleActive(widget.transaction!.id!, false);

        // crear nueva
        final newSched = ScheduledTransaction(
          type: _type,
          accountId: _accountId!,
          linkedAccountId: _type == 'transfer' ? _linkedAccountId : null,
          categoryId: _type == 'transfer' ? null : _categoryId,
          amount: amount,
          currency: _currency,
          startDate: startIso,
          endDate: null,
          frequency: _frequency,
          nextRun: startIso,
          isActive: _isActive ? 1 : 0,
          note: note,
        );

        final newId = await _repo.insert(newSched);   // insert => int
        final inserted = newSched.copyWith(id: newId);

        // materialización inmediata si arranca hoy y está activa
        if (_isActive && start.isAtSameMomentAs(today)) {
          await _materializeNow(inserted);
          final next = _advance(today, _frequency);
          await _repo.update(inserted.copyWith(nextRun: _fmt.format(next)));
        }
      } else {
        // actualizar campos simples
        final upd = widget.transaction!.copyWith(
          isActive: _isActive ? 1 : 0,
          note: note,
          currency: _currency,
          amount: amount,
        );
        await _repo.update(upd);
      }

      if (!mounted) return;
      Navigator.pop(context, true); // <- avisa a la lista para recargar
      return;
    }

    // CREAR
    final sched = ScheduledTransaction(
      type: _type,
      accountId: _accountId!,
      linkedAccountId: _type == 'transfer' ? _linkedAccountId : null,
      categoryId: _type == 'transfer' ? null : _categoryId,
      amount: amount,
      currency: _currency,
      startDate: startIso,
      endDate: null,
      frequency: _frequency,
      nextRun: startIso,
      isActive: _isActive ? 1 : 0,
      note: note,
    );

    final newId = await _repo.insert(sched); // insert => int
    final inserted = sched.copyWith(id: newId);

    if (_isActive && start.isAtSameMomentAs(today)) {
      await _materializeNow(inserted);
      final next = _advance(today, _frequency);
      await _repo.update(inserted.copyWith(nextRun: _fmt.format(next)));
    }

    if (!mounted) return;
    Navigator.pop(context, true); // <- avisa a la lista para recargar
  }

  Future<void> _materializeNow(ScheduledTransaction s) async {
    final dateIso = _fmt.format(_floorDate(DateTime.now()));
    if (s.type == 'income') {
      await _txService.addIncome(
        accountId: s.accountId,
        amount: s.amount,
        currency: s.currency,
        categoryId: s.categoryId,
        dateIso: dateIso,
        note: s.note,
      );
    } else if (s.type == 'expense') {
      await _txService.addExpense(
        accountId: s.accountId,
        amount: s.amount,
        currency: s.currency,
        categoryId: s.categoryId,
        dateIso: dateIso,
        note: s.note,
      );
    } else if (s.type == 'transfer' && s.linkedAccountId != null) {
      await _txService.addTransfer(
        fromAccountId: s.accountId,
        toAccountId: s.linkedAccountId!,
        amount: s.amount,
        currency: s.currency,
        dateIso: dateIso,
        note: s.note,
      );
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('scheduled.delete_title')),
        content: Text(tr('scheduled.delete_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('common.delete'))),
        ],
      ),
    );
    if (ok != true) return;

    await _repo.delete(widget.transaction!.id!);
    if (!mounted) return;
    Navigator.pop(context, true); // <- que la lista recargue
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ===== Value-object para comparar cambios estructurales =====
class ScheduledTransactionFields {
  final String type;
  final int? accountId;
  final int? linkedId;
  final int? categoryId;
  final double amount;
  final String currency;
  final String frequency;
  final String startIso;

  const ScheduledTransactionFields({
    required this.type,
    required this.accountId,
    required this.linkedId,
    required this.categoryId,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.startIso,
  });

  @override
  bool operator ==(Object other) =>
      other is ScheduledTransactionFields &&
          type == other.type &&
          accountId == other.accountId &&
          linkedId == other.linkedId &&
          categoryId == other.categoryId &&
          amount == other.amount &&
          currency == other.currency &&
          frequency == other.frequency &&
          startIso == other.startIso;

  @override
  int get hashCode => Object.hash(type, accountId, linkedId, categoryId, amount, currency, frequency, startIso);
}
