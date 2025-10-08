import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../screen/manage_accounts_screen.dart';

class AccountSelector extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;          // [{id,name,...}]
  final Function(int) onSelect;
  final int? initialSelectedId;
  final VoidCallback? onManageTapOverride;            // opcional: si quieres manejar la navegación afuera

  const AccountSelector({
    Key? key,
    required this.accounts,
    required this.onSelect,
    this.initialSelectedId,
    this.onManageTapOverride,
  }) : super(key: key);

  @override
  _AccountSelectorState createState() => _AccountSelectorState();
}

class _AccountSelectorState extends State<AccountSelector> {
  int? selectedAccount;

  @override
  void initState() {
    super.initState();
    selectedAccount = widget.initialSelectedId;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showAccountModal,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              selectedAccount != null
                  ? (widget.accounts.firstWhere(
                    (acc) => acc['id'] == selectedAccount,
                orElse: () => {'name': 'unknown_account'.tr()},
              )['name'] as String)
                  : "select_account".tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Icon(Icons.arrow_drop_down,
                size: 24, color: Theme.of(context).iconTheme.color),
          ],
        ),
      ),
    );
  }

  void _showAccountModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        final textColor = Theme.of(context).textTheme.titleLarge?.color;

        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6, // igual que category
          child: Column(
            children: [
              // Encabezado: título + "+"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("accounts".tr(),
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: textColor,                // mismo color que el texto (oscuro/claro)
                    tooltip: 'add'.tr(),
                    onPressed: () async {
                      // Si te interesa controlar afuera, respeta el override
                      if (widget.onManageTapOverride != null) {
                        widget.onManageTapOverride!();
                        return;
                      }
                      // Navegación simple para testing
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManageAccountsScreen(
                            accounts: widget.accounts,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Lista de cuentas
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
