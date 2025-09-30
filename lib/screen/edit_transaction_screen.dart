import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/database_helper.dart';
import '../utils/exchange_rate_service.dart';
import '../utils/settings_helper.dart';
import '../widgets/selectors/account_selector.dart';
import '../widgets/selectors/category_selector.dart';
import '../screen/select_currency_screen.dart';

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
    selectedDate = DateTime.parse(widget.transaction['date']);
    amountController = TextEditingController(text: widget.transaction['amount'].toString());
    noteController = TextEditingController(text: widget.transaction['note'] ?? '');
    selectedType = widget.transaction['type'];
    selectedAccount = widget.transaction['account_id'];
    selectedCategory = widget.transaction['category_id'];
    linkedAccount = widget.transaction['linked_account_id'];
    selectedCurrency = widget.transaction['currency'] ?? 'DOP';

    amountController.addListener(_updateConvertedAmount);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    mainCurrency = await SettingsHelper().getMainCurrency();
    final currencies = await _dbHelper.getAllCurrenciesCodes();

    setState(() {
      availableCurrencies = currencies.take(4).toList();
    });

    _updateConvertedAmount();
  }

  void _updateConvertedAmount() async {
    if (amountController.text.isEmpty || mainCurrency == null) {
      setState(() => convertedAmount = null);
      return;
    }
    try {
      final rate = await _exchangeRateService.getExchangeRate(context, selectedCurrency, mainCurrency!);
      setState(() {
        convertedAmount = (double.tryParse(amountController.text) ?? 0.0) * rate;
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
            AccountSelector(
              accounts: widget.accounts,
              initialSelectedId: selectedAccount,
              onSelect: (id) {
                setState(() {
                  selectedAccount = id;
                  _updateConvertedAmount();
                });
              },
            ),
            const SizedBox(height: 15),
            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts.where((acc) => acc['id'] != selectedAccount).toList(),
                initialSelectedId: linkedAccount,
                onSelect: (id) => setState(() => linkedAccount = id),
              ),
            if (selectedType != 'transfer')
              CategorySelector(
                categories: widget.categories,
                transactionType: selectedType,
                initialSelectedId: selectedCategory,
                onSelect: (id) => setState(() => selectedCategory = id),
              ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: amountController,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                    decoration: InputDecoration(
                      labelText: 'amount'.tr(),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildCurrencyDropdown(),
                ),
              ],
            ),
            if (convertedAmount != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('≈ ${convertedAmount!.toStringAsFixed(2)} $mainCurrency', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ),
            const SizedBox(height: 15),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'note_optional'.tr(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 25),
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
        labelText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      isExpanded: true,
    );
  }


  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: () async {
        DateTime? picked = await showDatePicker(
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
              Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? typeColor : null)),
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

  void _changeType(String type) {
    setState(() {
      selectedType = type;
      selectedCategory = null;
      linkedAccount = null;
    });
  }

  Future<void> _updateTransaction() async {
    double amount = double.tryParse(amountController.text) ?? 0.0;
    Map<String, dynamic> updatedTransaction = {
      'account_id': selectedAccount,
      'linked_account_id': selectedType == 'transfer' ? linkedAccount : null,
      'type': selectedType,
      'amount': amount,
      'currency': selectedCurrency,
      'category_id': selectedType == 'transfer' ? null : selectedCategory,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'note': noteController.text.isEmpty ? null : noteController.text,
    };

    await _dbHelper.updateTransaction(widget.transaction['id'], updatedTransaction);
    Navigator.pop(context, true);
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
              await _dbHelper.deleteTransaction(widget.transaction['id']);
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
