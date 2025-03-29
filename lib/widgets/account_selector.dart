import 'package:flutter/material.dart';

class AccountSelector extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  final Function(int) onSelect;
  final int? initialSelectedId; // ✅ Nuevo parámetro opcional

  const AccountSelector({
    Key? key,
    required this.accounts,
    required this.onSelect,
    this.initialSelectedId, // ✅ Se agrega al constructor
  }) : super(key: key);

  @override
  _AccountSelectorState createState() => _AccountSelectorState();
}

class _AccountSelectorState extends State<AccountSelector> {
  int? selectedAccount;

  @override
  void initState() {
    super.initState();
    selectedAccount = widget.initialSelectedId; // ✅ Se inicializa con el valor recibido
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAccountModal(),
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
              selectedAccount != null
                  ? widget.accounts.firstWhere(
                    (acc) => acc['id'] == selectedAccount,
                orElse: () => {'name': 'Cuenta desconocida'},
              )['name']
                  : "Seleccionar Cuenta",
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.arrow_drop_down, size: 24, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showAccountModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              const Text("Cuentas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView(
                  children: widget.accounts.map((account) {
                    return ListTile(
                      title: Text(account['name']),
                      onTap: () {
                        setState(() => selectedAccount = account['id']);
                        widget.onSelect(account['id']);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
