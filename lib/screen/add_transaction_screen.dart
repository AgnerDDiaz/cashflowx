import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/exchange_rate_service.dart';
import '../services/transaction_service.dart';
import '../repositories/exchange_rates_repository.dart';
import '../utils/settings_helper.dart';
import '../utils/app_colors.dart';

import '../widgets/selectors/account_selector.dart';
import '../widgets/selectors/category_selector.dart';
import '../widgets/selectors/currency_selector.dart';

class AddTransactionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;   // seguimos usando Map para no romper selectores
  final List<Map<String, dynamic>> categories; // idem

  const AddTransactionScreen({
    Key? key,
    required this.accounts,
    required this.categories,
  }) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  DateTime selectedDate = DateTime.now();

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  final _exchangeRateService = ExchangeRateService();
  final _txService = TransactionService();
  final _ratesRepo = ExchangeRatesRepository();

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
    amountController.addListener(_updateConvertedAmount);

    // Leer argumentos de la ruta y precargar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        if (args.containsKey('date')) {
          selectedDate = args['date'];
        }
        if (args.containsKey('account_id')) {
          selectedAccount = args['account_id'];
        }
      }

      _updateConvertedAmount();
      setState(() {}); // refresca UI
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    mainCurrency = await SettingsHelper().getMainCurrency() ?? 'DOP';

    final list = await _buildAvailableCurrencies(mainCurrency!);

    setState(() {
      selectedCurrency = mainCurrency!;
      availableCurrencies = list; // ← lista completa, sin truncar
    });

    _updateConvertedAmount();
  }

  Future<List<String>> _buildAvailableCurrencies(String main) async {
    final codes = await _ratesRepo.allCurrencies(); // base + target desde repo
    final set = <String>{...codes, main}; // garantiza presencia de la principal
    final list = set.toList()
      ..sort((a, b) {
        if (a == main) return -1;
        if (b == main) return 1;
        return a.compareTo(b);
      });
    return list;
  }



  void _updateConvertedAmount() async {
    if (amountController.text.isEmpty || mainCurrency == null) {
      setState(() => convertedAmount = null);
      return;
    }

    try {
      final amount = double.tryParse(amountController.text) ?? 0.0;
      if (amount <= 0) {
        setState(() => convertedAmount = null);
        return;
      }
      final rate = await _exchangeRateService.getExchangeRate(
        selectedCurrency,
        mainCurrency!,
        context: context,
      );
      setState(() {
        convertedAmount = amount * rate;
      });
    } catch (e) {
      // Si falla, deja el preview vacío
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
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // Solo la primera vez
    if (args != null && selectedAccount == null) {
      if (args.containsKey('date')) selectedDate = args['date'];
      if (args.containsKey('account_id')) selectedAccount = args['account_id'];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("add_transaction".tr(), style: Theme.of(context).textTheme.titleLarge),
      ),
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
              onSelect: (selectedId) {
                setState(() {
                  selectedAccount = selectedId;
                  linkedAccount = null;
                });
                _updateConvertedAmount();
              },
            ),
            const SizedBox(height: 15),

            // Cuenta destino (solo transfer)
            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts.where((a) => a['id'] != selectedAccount).toList(),
                onSelect: (selectedId) => setState(() => linkedAccount = selectedId),
              ),

            // Categoría (no transfer)
            if (selectedType != 'transfer')
              CategorySelector(
                categories: widget.categories,
                transactionType: selectedType,
                onSelect: (selectedId) => setState(() => selectedCategory = selectedId),
              ),

            const SizedBox(height: 15),

            // Monto + Moneda
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    controller: amountController,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+([.]\d{0,2})?'))],
                    decoration: InputDecoration(
                      labelText: "amount".tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: CurrencySelector(
                    currencies: availableCurrencies.map((c) => {"code": c, "name": ""}).toList(),
                    initialSelectedCode: selectedCurrency,
                    onSelect: (code) {
                      setState(() => selectedCurrency = code);
                      _updateConvertedAmount();
                    },
                    onAddSelected: (code) {
                      if (!availableCurrencies.contains(code)) {
                        setState(() => availableCurrencies = [code, ...availableCurrencies]);
                      }
                      // Si quieres que quede seleccionada de inmediato, ya lo hace CurrencySelector,
                      // pero mantenemos el estado local por coherencia:
                      setState(() => selectedCurrency = code);
                      _updateConvertedAmount();
                    },
                  ),

                ),
              ],
            ),

            if (convertedAmount != null && mainCurrency != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '≈ ${convertedAmount!.toStringAsFixed(2)} $mainCurrency',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ),

            const SizedBox(height: 15),

            // Nota
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "note_optional".tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),

            const SizedBox(height: 25),

            // Guardar
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(backgroundColor: _getButtonColor()),
              child: Center(
                child: Text("save_transaction".tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['expenses'.tr(), 'income'.tr(), 'transfer'.tr()].map((t) {
        final dbType = _mapTranslatedTypeToDB(t);
        final isSelected = dbType == selectedType;

        Color typeColor;
        switch (dbType) {
          case 'expense':
            typeColor = Colors.red;
            break;
          case 'income':
            typeColor = Colors.green;
            break;
          case 'transfer':
            typeColor = Colors.grey;
            break;
          default:
            typeColor = Colors.red;
        }

        return GestureDetector(
          onTap: () => _changeType(t),
          child: Column(
            children: [
              Text(
                t,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? typeColor : null,
                ),
              ),
              if (isSelected)
                Container(height: 3, width: 50, color: typeColor),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _mapTranslatedTypeToDB(String type) {
    if (type == 'expenses'.tr()) return 'expense';
    if (type == 'income'.tr()) return 'income';
    if (type == 'transfer'.tr()) return 'transfer';
    return 'expense';
  }

  void _changeType(String type) {
    setState(() {
      selectedType = _mapTranslatedTypeToDB(type);
      selectedCategory = null;
      linkedAccount = null;
    });
  }

  Color _getButtonColor() {
    switch (selectedType) {
      case 'income':
        return Colors.green;
      case 'expense':
        return Colors.red;
      case 'transfer':
        return Colors.grey;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Future<void> _saveTransaction() async {
    if (selectedAccount == null || amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("complete_fields".tr())),
      );
      return;
    }

    final amount = double.tryParse(amountController.text) ?? 0.0;
    final dateIso = DateFormat('yyyy-MM-dd').format(selectedDate);
    final note = noteController.text.isEmpty ? null : noteController.text;

    try {
      if (selectedType == 'transfer') {
        if (linkedAccount == null || linkedAccount == selectedAccount) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("select_destination_account".tr())),
          );
          return;
        }
        await _txService.addTransfer(
          amount: amount,
          fromAccountId: selectedAccount!,
          toAccountId: linkedAccount!,
          currency: selectedCurrency,
          dateIso: dateIso,
          note: note,
        );
      } else if (selectedType == 'income') {
        await _txService.addIncome(
          accountId: selectedAccount!,
          amount: amount,
          currency: selectedCurrency,
          categoryId: selectedCategory,
          dateIso: dateIso,
          note: note,
        );
      } else {
        // expense
        if (selectedCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("select_category".tr())),
          );
          return;
        }
        await _txService.addExpense(
          accountId: selectedAccount!,
          amount: amount,
          currency: selectedCurrency,
          categoryId: selectedCategory,
          dateIso: dateIso,
          note: note,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("error_saving_transaction".tr(args: [e.toString()]))),
      );
    }
  }
}
