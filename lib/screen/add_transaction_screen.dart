import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../widgets/account_selector.dart';
import '../widgets/category_selector.dart';

class AddTransactionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;


  const AddTransactionScreen(
      {Key? key, required this.accounts, required this.categories})
      : super(key: key);

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
    return Scaffold(
      appBar: AppBar(title: const Text("Agregar Transacción")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransactionTypeSelector(),
            const SizedBox(height: 12),
            _buildDateSelector(),
            const SizedBox(height: 12),

            /// 🔹 **Selector de Cuenta (Cuenta de origen)**
            AccountSelector(
              accounts:
                  widget.accounts, // ✅ Se pasa la lista de cuentas completas
              onSelect: (selectedId) {
                setState(() {
                  selectedAccount = selectedId;
                  linkedAccount =
                      null; // 🚀 Reiniciar la cuenta destino si cambia la cuenta origen
                });
              },
            ),

            const SizedBox(height: 12),

            /// 🔹 **Selector de Cuenta (Cuenta de destino para transferencias)**
            if (selectedType == 'transfer')
              AccountSelector(
                accounts: widget.accounts
                    .where((account) =>
                        account['id'] !=
                        selectedAccount) // 🔥 Filtrar la cuenta seleccionada
                    .toList(),
                onSelect: (selectedId) {
                  setState(() {
                    linkedAccount = selectedId;
                  });
                },
              ),

            /// 🔹 **Selector de Categoría (Solo para Ingresos y Gastos)**
            if (selectedType != 'transfer')
              CategorySelector(
                categories:
                    widget.categories, // ✅ Se pasa la lista de categorías
                transactionType: selectedType, // ✅ Filtra entre ingresos/gastos
                onSelect: (selectedId) {
                  setState(() {
                    selectedCategory = selectedId;
                  });
                },
              ),

            const SizedBox(height: 12),

            TextField(
              keyboardType: TextInputType.number,
              controller: amountController,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')) // Permite decimales con dos decimales
              ],
              decoration: InputDecoration(
                labelText: "Monto",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    width: 1,
                    style: BorderStyle.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: "Nota (opcional)",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(
                      width: 1,
                      style: BorderStyle.none,
                    )
                ),
              ),
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Center(
                child: Text(
                  "Guardar Transacción",
                  style: TextStyle(fontSize: 16, color: Colors.white),
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
              style: const TextStyle(fontSize: 16),
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
                ),
              ),
              if (isSelected)
                Container(
                  height: 3,
                  width: 50,
                  color: Colors.red,
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

    // 🔍 Obtener la cuenta seleccionada
    final selectedAcc = widget.accounts.firstWhere((acc) => acc['id'] == selectedAccount);
    final currentBalance = selectedAcc['balance'] as double;
    final balanceMode = selectedAcc['balance_mode'] ?? 'default'; // En caso de que falte


    // ✅ Validación para transferencias y gastos (solo si es tipo 'debit')
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
