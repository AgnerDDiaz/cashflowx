import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../screen/edit_transaction_screen.dart';
import '../utils/app_colors.dart';
import '../utils/exchange_rate_service.dart';
import '../utils/settings_helper.dart';

class TransactionItem extends StatefulWidget {
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
  _TransactionItemState createState() => _TransactionItemState();
}

class _TransactionItemState extends State<TransactionItem> {
  final ExchangeRateService _exchangeRateService = ExchangeRateService();
  double? convertedAmount;
  String? mainCurrency;

  @override
  void initState() {
    super.initState();
    _loadConvertedAmount();
  }

  Future<void> _loadConvertedAmount() async {
    String transactionCurrency = widget.transaction['currency'] ?? 'DOP';
    double amount = widget.transaction['amount'] ?? 0.0;

    mainCurrency = await SettingsHelper().getMainCurrency();

    if (transactionCurrency != mainCurrency) {
      double converted = await _exchangeRateService.convertAmount(
        context,
        amount,
        transactionCurrency,
      );
      setState(() {
        convertedAmount = converted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String type = widget.transaction['type'];
    double amount = widget.transaction['amount'] ?? 0.0;
    String category = _getCategoryName(widget.transaction['category_id']);
    String account = _getAccountName(widget.transaction['account_id']);
    String transactionCurrency = widget.transaction['currency'] ?? 'DOP';

    String linkedAccountName = widget.transaction['linked_account_id'] != null
        ? _getAccountName(widget.transaction['linked_account_id'])
        : '';

    if (type == 'transfer') {
      account = "$account → $linkedAccountName";
      category = "transfer".tr();
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$transactionCurrency ${amount.toStringAsFixed(2)}",
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (convertedAmount != null && mainCurrency != null)
              Text(
                "≈ ${convertedAmount!.toStringAsFixed(2)} $mainCurrency",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
        onTap: () async {
          bool? updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditTransactionScreen(
                transaction: widget.transaction,
                accounts: widget.accounts,
                categories: widget.categories,
              ),
            ),
          );

          if (updated == true) {
            widget.onTransactionUpdated();
          }
        },
      ),
    );
  }

  String _getCategoryName(int? categoryId) {
    if (categoryId == null) return "no_category".tr();
    var category = widget.categories.firstWhere(
          (cat) => cat['id'] == categoryId,
      orElse: () => {'name': 'no_category'.tr()},
    );
    return category['name'];
  }

  String _getAccountName(int? accountId) {
    if (accountId == null) return "unknown".tr();
    var account = widget.accounts.firstWhere(
          (acc) => acc['id'] == accountId,
      orElse: () => {'name': 'unknown'.tr()},
    );
    return account['name'];
  }
}
