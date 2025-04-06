import 'package:flutter/material.dart';
import '../screen/edit_transaction_screen.dart';
import '../utils/app_colors.dart'; // 📌 Asegúrate de importar AppColors

class TransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onTransactionUpdated;

  const TransactionItem({
    Key? key,
    required this.transaction,
    required this.accounts,
    required this.categories,
    required this.onTransactionUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String type = transaction['type'];
    double amount = transaction['amount'] ?? 0.0;
    String category = _getCategoryName(transaction['category_id']);
    String account = _getAccountName(transaction['account_id']);

    String linkedAccountName = transaction['linked_account_id'] != null
        ? _getAccountName(transaction['linked_account_id'])
        : '';

    if (type == 'transfer') {
      account = "$account → $linkedAccountName";
      category = "Transferencia";
    }

    Color amountColor = type == 'income'
        ? AppColors.ingresoColor
        : type == 'expense'
        ? AppColors.gastoColor
        : AppColors.balanceColor;

    IconData icon = type == 'income'
        ? Icons.arrow_upward
        : type == 'expense'
        ? Icons.arrow_downward
        : Icons.compare_arrows;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: Icon(icon, color: amountColor),
        title: Text(
          category,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
        ),
        subtitle: Text(
          account,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Text(
          "\$${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () async {
          bool? updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditTransactionScreen(
                transaction: transaction,
                accounts: accounts,
                categories: categories,
              ),
            ),
          );

          if (updated == true) {
            onTransactionUpdated();
          }
        },
      ),
    );
  }

  String _getCategoryName(int? categoryId) {
    if (categoryId == null) return "Sin Categoría";
    var category = categories.firstWhere(
          (cat) => cat['id'] == categoryId,
      orElse: () => {'name': 'Sin Categoría'},
    );
    return category['name'];
  }

  String _getAccountName(int? accountId) {
    if (accountId == null) return "Desconocida";
    var account = accounts.firstWhere(
          (acc) => acc['id'] == accountId,
      orElse: () => {'name': 'Desconocida'},
    );
    return account['name'];
  }
}
