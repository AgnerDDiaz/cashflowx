import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/database_helper.dart';
import '../utils/exchange_rate_service.dart';
import '../utils/currency_service.dart';
import '../utils/settings_helper.dart';
import '../widgets/account_selector.dart';
import '../widgets/category_selector.dart';

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
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ExchangeRateService _exchangeRateService = ExchangeRateService();
  final CurrencyService _currencyService = CurrencyService();

  String selectedType = 'expense';
  int? selectedAccount;
  int? selectedCategory;
  int? linkedAccount;
  String selectedCurrency = 'USD';
  double? convertedAmount;
  List<Map<String, String>> availableCurrencies = [];
  String? mainCurrency;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.parse(widget.transaction['date']);
    amountController = TextEditingController(text: widget.transaction['amount'].toString());
    noteController = TextEditingController(text: widget.transaction['note'] ?? '');
    selectedType = widget.transaction['type'];
    selectedAccount = widget.transaction['account_id'];
    selectedCategory = widget.transaction['category_id'];
    linkedAccount = widget.transaction['linked_account_id'];
    selectedCurrency = widget.transaction['currency'] ?? 'USD';

    amountController.addListener(_updateConvertedAmount);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      mainCurrency = await SettingsHelper().getMainCurrency();
      final currencies = await _currencyService.getSupportedCurrencies();
      setState(() {
        availableCurrencies = currencies;
      });
      _updateConvertedAmount();
    } catch (e) {
      print('Error cargando monedas: $e');
    }
  }

  void _changeType(String type) {
    setState(() {
      selectedType = _mapTypeToDB(type);
      selectedCategory = null;
      linkedAccount = null;
    });
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
      appBar: AppBar(title: Text("edit_transaction".tr(), style: Theme.of(context).textTheme.titleLarge)),
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
              onSelect: (id) {
                setState(() {
                  selectedAccount = id;
                  _updateConvertedAmount();
                });
              },
              initialSelectedId: selectedAccount,
            ),
            const SizedBox(height: 15),
            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts.where((acc) => acc['id'] != selectedAccount).toList(),
                onSelect: (id) => setState(() => linkedAccount = id),
                initialSelectedId: linkedAccount,
              ),
            if (selectedType != 'transfer')
              CategorySelector(
                categories: widget.categories,
                transactionType: selectedType,
                onSelect: (id) => setState(() => selectedCategory = id),
                initialSelectedId: selectedCategory,
              ),
            const SizedBox(height: 15),
            TextField(
              keyboardType: TextInputType.number,
              controller: amountController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
              decoration: InputDecoration(
                labelText: "amount".tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 8),
            _buildCurrencySelector(),
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _updateTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ingresoColor,
                    ),
                    child: Text("update".tr(), style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmDeleteTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorColor,
                    ),
                    child: Text("delete".tr(), style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelector() {
    return DropdownButtonFormField<String>(
      value: selectedCurrency,
      decoration: InputDecoration(
        labelText: 'Moneda',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      isExpanded: true,
      items: availableCurrencies.map((currency) {
        return DropdownMenuItem(
          value: currency['code'],
          child: Text("${currency['code']} - ${currency['name']}", overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            selectedCurrency = value;
            _updateConvertedAmount();
          });
        }
      },
    );
  }

  void _confirmDeleteTransaction() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("delete_transaction".tr()),
        content: Text("delete_transaction_confirmation".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("cancel".tr()),
          ),
          TextButton(
            onPressed: () async {
              await _deleteTransaction();
              Navigator.pop(context, true);
            },
            child: Text("delete".tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
    final types = ['expense', 'income', 'transfer']; // << Trabajamos con los valores internos

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: types.map((typeKey) {
        bool isSelected = typeKey == selectedType;
        String displayText;
        Color typeColor;

        // Traducción y color
        switch (typeKey) {
          case 'expense':
            displayText = 'expenses'.tr();
            typeColor = Colors.red;
            break;
          case 'income':
            displayText = 'income'.tr();
            typeColor = Colors.green;
            break;
          case 'transfer':
            displayText = 'transfer'.tr();
            typeColor = Colors.grey;
            break;
          default:
            displayText = '';
            typeColor = Colors.black;
        }

        return GestureDetector(
          onTap: () => _changeType(typeKey),
          child: Column(
            children: [
              Text(
                displayText,
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


  String _mapTypeToDB(String type) {
    switch (type) {
      case 'Gasto':
      case 'expenses':
        return 'expense';
      case 'Ingreso':
      case 'income':
        return 'income';
      case 'Transferencia':
      case 'transfer':
        return 'transfer';
      default:
        return 'expense';
    }
  }

  Future<void> _updateTransaction() async {
    double amount = double.tryParse(amountController.text) ?? 0.0;

    final selectedAcc = widget.accounts.firstWhere((acc) => acc['id'] == selectedAccount);
    final currentBalance = selectedAcc['balance'] as double;
    final balanceMode = selectedAcc['balance_mode'] ?? 'default';

    if ((selectedType == 'transfer' || selectedType == 'expense') && balanceMode == 'debit' && amount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("insufficient_balance".tr())),
      );
      return;
    }

    Map<String, dynamic> updatedTransaction = {
      'account_id': selectedAccount,
      'linked_account_id': selectedType == 'transfer' ? linkedAccount : null,
      'type': selectedType,
      'amount': amount,
      'currency': selectedCurrency,
      'category_id': selectedType == 'transfer' ? null : selectedCategory,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'note': noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
    };

    await _dbHelper.updateTransaction(widget.transaction['id'], updatedTransaction);
    Navigator.pop(context, true);
  }

  Future<void> _deleteTransaction() async {
    await _dbHelper.deleteTransaction(widget.transaction['id']);
    Navigator.pop(context, true);
  }
}
