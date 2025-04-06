import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../widgets/account_selector.dart';
import '../widgets/category_selector.dart';

class AddTransactionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;

  const AddTransactionScreen({
    Key? key,
    required this.accounts,
    required this.categories,
  }) : super(key: key);

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  DateTime selectedDate = DateTime.now();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String selectedType = 'expense';
  int? selectedAccount;
  int? selectedCategory;
  int? linkedAccount;

  void _changeType(String type) {
    setState(() {
      selectedType = _mapTypeToDB(type);
      selectedCategory = null;
      linkedAccount = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('date')) {
      selectedDate = args['date'];
    }

    return Scaffold(
      appBar: AppBar(title: Text("Agregar Transacción", style: Theme.of(context).textTheme.titleLarge)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionTypeSelector(),
            const SizedBox(height: 15),
            _buildDateSelector(),
            const SizedBox(height: 15),

            /// Selector de cuenta origen
            AccountSelector(
              accounts: widget.accounts,
              onSelect: (selectedId) {
                setState(() {
                  selectedAccount = selectedId;
                  linkedAccount = null;
                });
              },
            ),

            const SizedBox(height: 15),

            /// Selector de cuenta destino para transferencias
            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts.where((account) => account['id'] != selectedAccount).toList(),
                onSelect: (selectedId) {
                  setState(() {
                    linkedAccount = selectedId;
                  });
                },
              ),

            /// Selector de categoría
            if (selectedType != 'transfer')
              CategorySelector(
                categories: widget.categories,
                transactionType: selectedType,
                onSelect: (selectedId) {
                  setState(() {
                    selectedCategory = selectedId;
                  });
                },
              ),

            const SizedBox(height: 15),

            TextField(
              keyboardType: TextInputType.number,
              controller: amountController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
              decoration: InputDecoration(
                labelText: "Monto",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "Nota (opcional)",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Center(
                child: Text(
                  "Guardar Transacción",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
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

  Future<void> _saveTransaction() async {
    if (selectedAccount == null || amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos correctamente")),
      );
      return;
    }

    double amount = double.tryParse(amountController.text) ?? 0.0;

    final selectedAcc = widget.accounts.firstWhere((acc) => acc['id'] == selectedAccount);
    final currentBalance = selectedAcc['balance'] as double;
    final balanceMode = selectedAcc['balance_mode'] ?? 'default';

    if ((selectedType == 'transfer' || selectedType == 'expense') &&
        balanceMode == 'debit' &&
        amount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saldo insuficiente para realizar esta transacción")),
      );
      return;
    }

    Map<String, dynamic> transaction = {
      'account_id': selectedAccount,
      'linked_account_id': selectedType == 'transfer' ? linkedAccount : null,
      'type': selectedType,
      'amount': amount,
      'category_id': selectedType == 'transfer' ? null : selectedCategory,
      'date': DateFormat('yyyy-MM-dd').format(selectedDate),
      'note': noteController.text.isEmpty ? null : noteController.text,
    };

    await _dbHelper.addTransaction(transaction);
    Navigator.pop(context, true);
  }
}
