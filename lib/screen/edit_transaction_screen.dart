import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/exchange_rate_service.dart';
import '../services/transaction_service.dart';
import '../repositories/exchange_rates_repository.dart';
import '../utils/app_colors.dart';
import '../utils/settings_helper.dart';

import '../widgets/selectors/account_selector.dart';
import '../widgets/selectors/category_selector.dart';
import '../widgets/selectors/currency_selector.dart';

import '../screen/select_currency_screen.dart';

import '../models/transaction.dart'; // AppTransaction

class EditTransactionScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;

  const EditTransactionScreen({
    Key? key,
    required this.transaction,
    required this.accounts,
    required this.categories,
  }) : super(key: key);

  @override
  _EditTransactionScreenState createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late DateTime selectedDate;
  late TextEditingController amountController;
  late TextEditingController noteController;

  final ExchangeRateService _exchangeRateService = ExchangeRateService();
  final TransactionService _txService = TransactionService();
  final ExchangeRatesRepository _ratesRepo = ExchangeRatesRepository();

  String selectedType = 'expense';
  int? selectedAccount;
  int? selectedCategory;
  int? linkedAccount;

  String selectedCurrency = 'DOP';
  double? convertedAmount;
  List<String> availableCurrencies = [];
  String? mainCurrency;

  @override
  void initState() {
    super.initState();

    selectedDate = DateTime.parse(widget.transaction['date'] as String);
    amountController = TextEditingController(
      text: (widget.transaction['amount'] as num).toString(),
    );
    noteController = TextEditingController(
      text: widget.transaction['note'] ?? '',
    );
    selectedType = widget.transaction['type'] as String;
    selectedAccount = widget.transaction['account_id'] as int?;
    selectedCategory = widget.transaction['category_id'] as int?;
    linkedAccount = widget.transaction['linked_account_id'] as int?;
    selectedCurrency = (widget.transaction['currency'] as String?) ?? 'DOP';

    amountController.addListener(_updateConvertedAmount);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';

    // Traer códigos de monedas desde la BD (tabla exchange_rates)
    List<String> codes = await _ratesRepo.allBaseCurrencyCodes();
    codes = codes.toSet().toList();

    // Asegurar presencia de principales
    for (final must in [mainCurrency!, 'USD', 'DOP']) {
      if (!codes.contains(must)) codes.add(must);
    }

    setState(() {
      availableCurrencies = codes.take(6).toList();
    });

    _updateConvertedAmount();
  }

  void _updateConvertedAmount() async {
    if (amountController.text.isEmpty || mainCurrency == null) {
      setState(() => convertedAmount = null);
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0.0;
    if (amount <= 0) {
      setState(() => convertedAmount = null);
      return;
    }

    try {
      final rate = await _exchangeRateService.getExchangeRate(
        selectedCurrency,
        mainCurrency!,
        context: context,
      );
      setState(() {
        convertedAmount = amount * rate;
      });
    } catch (_) {
      setState(() => convertedAmount = null);
    }
  }

  @override
  void dispose() {
    amountController.removeListener(_updateConvertedAmount);
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('edit_transaction'.tr(), style: Theme.of(context).textTheme.titleLarge)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionTypeSelector(),
            const SizedBox(height: 15),
            _buildDateSelector(),
            const SizedBox(height: 15),

            // Cuenta origen
            AccountSelector(
              accounts: widget.accounts,
              initialSelectedId: selectedAccount,
              onSelect: (id) {
                setState(() {
                  selectedAccount = id;
                });
                _updateConvertedAmount();
              },
            ),
            const SizedBox(height: 15),

            // Cuenta destino (solo transfer)
            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts.where((acc) => acc['id'] != selectedAccount).toList(),
                initialSelectedId: linkedAccount,
                onSelect: (id) => setState(() => linkedAccount = id),
              ),

            // Categoría (no transfer)
            if (selectedType != 'transfer')
              CategorySelector(
                categories: widget.categories,
                transactionType: selectedType,
                initialSelectedId: selectedCategory,
                onSelect: (id) => setState(() => selectedCategory = id),
              ),

            const SizedBox(height: 15),

            // Monto + Moneda
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    controller: amountController,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+([.]\d{0,2})?'))],
                    decoration: InputDecoration(
                      labelText: 'amount'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: CurrencySelector(
                    currencies: availableCurrencies.map((c) => {"code": c, "name": ""}).toList(),
                    initialSelectedCode: selectedCurrency,
                    onSelect: (code) {
                      setState(() => selectedCurrency = code);
                      _updateConvertedAmount(); // <<< conserva el preview
                    },
                  ),
                ),
              ],
            ),

            if (convertedAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('≈ ${convertedAmount!.toStringAsFixed(2)} $mainCurrency',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ),

            const SizedBox(height: 15),

            // Nota
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'note_optional'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),

            const SizedBox(height: 25),

            // Guardar / Eliminar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateTransaction,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.ingresoColor),
                    child: Text('update'.tr(), style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmDeleteTransaction,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
                    child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('d MMM y').format(selectedDate), style: Theme.of(context).textTheme.bodyLarge),
            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    final types = ['expense', 'income', 'transfer'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: types.map((typeKey) {
        final isSelected = selectedType == typeKey;
        Color typeColor;
        String label;
        switch (typeKey) {
          case 'expense':
            label = 'expenses'.tr();
            typeColor = Colors.red;
            break;
          case 'income':
            label = 'income'.tr();
            typeColor = Colors.green;
            break;
          case 'transfer':
            label = 'transfer'.tr();
            typeColor = Colors.grey;
            break;
          default:
            label = '';
            typeColor = Colors.black;
        }
        return GestureDetector(
          onTap: () => _changeType(typeKey),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? typeColor : null,
                  )),
              if (isSelected) Container(height: 3, width: 50, color: typeColor),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _changeType(String type) {
    setState(() {
      selectedType = type;
      selectedCategory = null;
      linkedAccount = null;
    });
  }

  Future<void> _updateTransaction() async {
    final amount = double.tryParse(amountController.text) ?? 0.0;
    final dateIso = DateFormat('yyyy-MM-dd').format(selectedDate);
    final note = noteController.text.isEmpty ? null : noteController.text;

    if (selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('select_account'.tr())));
      return;
    }

    if (selectedType == 'transfer' && (linkedAccount == null || linkedAccount == selectedAccount)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('select_destination_account'.tr())));
      return;
    }
    if (selectedType != 'transfer' && selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('select_category'.tr())));
      return;
    }

    // Construir modelo actualizado con el MISMO id
    final updated = AppTransaction(
      id: widget.transaction['id'] as int,
      accountId: selectedAccount!,
      linkedAccountId: selectedType == 'transfer' ? linkedAccount : null,
      type: selectedType,
      amount: amount,
      currency: selectedCurrency,
      categoryId: selectedType == 'transfer' ? null : selectedCategory,
      date: dateIso,
      note: note,
    );

    try {
      await _txService.updateTransaction(updated);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('error_updating_transaction'.tr(args: [e.toString()]))),
      );
    }
  }

  void _confirmDeleteTransaction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_transaction'.tr()),
        content: Text('delete_transaction_confirmation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
            onPressed: () async {
              try {
                await _txService.deleteTransaction(widget.transaction['id'] as int);
                if (!mounted) return;
                Navigator.pop(context);
                Navigator.pop(context, true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('error_deleting_transaction'.tr(args: [e.toString()]))),
                );
              }
            },
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
