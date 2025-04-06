import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/database_helper.dart';
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

  String selectedType = 'expense';
  int? selectedAccount;
  int? selectedCategory;
  int? linkedAccount;

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
  }

  void _changeType(String type) {
    setState(() {
      selectedType = _mapTypeToDB(type);
      selectedCategory = null;
      linkedAccount = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("edit_transaction".tr(), style: Theme.of(context).textTheme.titleLarge)),
      body: Padding(
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
              onSelect: (id) => setState(() => selectedAccount = id),
              initialSelectedId: selectedAccount,
            ),

            const SizedBox(height: 15),

            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts.where((acc) => acc['id'] != selectedAccount).toList(),
                onSelect: (int id) => setState(() => linkedAccount = id),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "note_optional".tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
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

  void _confirmDeleteTransaction() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
        );
      },
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
          setState(() {
            selectedDate = pickedDate;
          });
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
            Text(
              DateFormat('d MMM y').format(selectedDate),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['Gasto', 'Ingreso', 'Transferencia'].map((type) {
        bool isSelected = _mapTypeToDB(type) == selectedType;
        return GestureDetector(
          onTap: () => _changeType(type),
          child: Column(
            children: [
              Text(
                type,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
              ),
              if (isSelected)
                Container(
                  height: 3,
                  width: 50,
                  color: Theme.of(context).primaryColor,
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
        return 'expense';
      case 'Ingreso':
        return 'income';
      case 'Transferencia':
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

    if ((selectedType == 'transfer' || selectedType == 'expense') &&
        balanceMode == 'debit' &&
        amount > currentBalance) {
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
