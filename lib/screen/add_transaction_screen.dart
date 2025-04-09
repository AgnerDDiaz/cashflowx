import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../utils/exchange_rate_service.dart';
import '../utils/settings_helper.dart';
import '../utils/app_colors.dart';
import '../widgets/account_selector.dart';
import '../widgets/category_selector.dart';
import '../screen/select_currency_screen.dart'; // Correcto

class AddTransactionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;

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
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ExchangeRateService _exchangeRateService = ExchangeRateService();

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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    mainCurrency = await SettingsHelper().getMainCurrency();
    final currencies = await _dbHelper.getAllCurrenciesCodes();

    setState(() {
      selectedCurrency = mainCurrency ?? 'DOP';
      availableCurrencies = currencies.take(4).toList();
    });

    _updateConvertedAmount();
  }

  void _updateConvertedAmount() async {
    if (selectedAccount == null || amountController.text.isEmpty || mainCurrency == null) {
      setState(() {
        convertedAmount = null;
      });
      return;
    }

    try {
      final rate = await _exchangeRateService.getExchangeRate(context, selectedCurrency, mainCurrency!);
      setState(() {
        convertedAmount = (double.tryParse(amountController.text) ?? 0.0) * rate;
      });
    } catch (e) {
      print('Error converting amount: $e');
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
      appBar: AppBar(title: Text("add_transaction".tr(), style: Theme.of(context).textTheme.titleLarge)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionTypeSelector(),
            const SizedBox(height: 15),
            _buildDateSelector(),
            const SizedBox(height: 15),
            AccountSelector(
              accounts: widget.accounts,
              onSelect: (selectedId) {
                setState(() {
                  selectedAccount = selectedId;
                  linkedAccount = null;
                  _updateConvertedAmount();
                });
              },
            ),
            const SizedBox(height: 15),
            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts.where((account) => account['id'] != selectedAccount).toList(),
                onSelect: (selectedId) => setState(() => linkedAccount = selectedId),
              ),
            if (selectedType != 'transfer')
              CategorySelector(
                categories: widget.categories,
                transactionType: selectedType,
                onSelect: (selectedId) => setState(() => selectedCategory = selectedId),
              ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: amountController,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                    decoration: InputDecoration(
                      labelText: "amount".tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildCurrencyDropdown(),
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
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "note_optional".tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 25),
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

  Widget _buildCurrencyDropdown() {
    final List<DropdownMenuItem<String>> items = [
      ...availableCurrencies.map((currencyCode) => DropdownMenuItem(
        value: currencyCode,
        child: Text(currencyCode, overflow: TextOverflow.ellipsis),
      )),
      DropdownMenuItem(
        value: 'other',
        child: Text("other_currency".tr()),
      ),
      if (!availableCurrencies.contains(selectedCurrency) && selectedCurrency != 'other')
        DropdownMenuItem(
          value: selectedCurrency,
          child: Text(selectedCurrency, overflow: TextOverflow.ellipsis),
        ),
    ];

    return DropdownButtonFormField<String>(
      value: selectedCurrency,
      items: items,
      onChanged: (value) async {
        if (value == 'other') {
          final selected = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelectCurrencyScreen()),
          );
          if (selected != null && selected is String) {
            setState(() => selectedCurrency = selected);
            _updateConvertedAmount();
          }
        } else {
          setState(() {
            selectedCurrency = value!;
            _updateConvertedAmount();
          });
        }
      },
      decoration: InputDecoration(
        labelText: "currency".tr(),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      isExpanded: true,
    );
  }


  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          setState(() => selectedDate = pickedDate);
        }
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
      children: ['expenses'.tr(), 'income'.tr(), 'transfer'.tr()].map((type) {
        bool isSelected = _mapTranslatedTypeToDB(type) == selectedType;

        Color typeColor;
        switch (_mapTranslatedTypeToDB(type)) {
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
          onTap: () => _changeType(type),
          child: Column(
            children: [
              Text(
                type,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? typeColor : null,
                ),
              ),
              if (isSelected)
                Container(
                  height: 3,
                  width: 50,
                  color: typeColor,
                ),
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

    double amount = double.tryParse(amountController.text) ?? 0.0;

    Map<String, dynamic> transaction = {
      'account_id': selectedAccount,
      'linked_account_id': selectedType == 'transfer' ? linkedAccount : null,
      'type': selectedType,
      'amount': amount,
      'currency': selectedCurrency,
      'category_id': selectedType == 'transfer' ? null : selectedCategory,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'note': noteController.text.isEmpty ? null : noteController.text,
    };

    await _dbHelper.addTransaction(transaction);
    Navigator.pop(context, true);
  }
}
