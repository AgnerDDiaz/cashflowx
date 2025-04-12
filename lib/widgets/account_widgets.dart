// === account_widgets.dart corregido ===

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/settings_helper.dart';

class AccountCategoryHeader extends StatelessWidget {
  final String category;
  final double totalBalance;
  final bool isHidden;
  final String mainCurrency;

  const AccountCategoryHeader({
    Key? key,
    required this.category,
    required this.totalBalance,
    required this.isHidden,
    required this.mainCurrency,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = totalBalance >= 0 ? AppColors.ingresoColor : AppColors.gastoColor;
    final textColor = isHidden ? Theme.of(context).disabledColor : color;

    final formatter = NumberFormat.currency(locale: 'en_US', symbol: mainCurrency); // 🔥 Aquí ya usamos el parámetro

    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  formatter.format(totalBalance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: Theme.of(context).scaffoldBackgroundColor,
            height: 6,
            thickness: 6,
          ),
        ],
      ),
    );
  }
}

class AccountTile extends StatelessWidget {
  final String name;
  final double balance;
  final String currency;
  final bool visible;
  final VoidCallback? onTap;

  const AccountTile({
    Key? key,
    required this.name,
    required this.balance,
    required this.currency,
    this.visible = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    if (!visible) {
      color = Theme.of(context).disabledColor;
    } else if (balance >= 0) {
      color = AppColors.ingresoColor;
    } else {
      color = AppColors.gastoColor;
    }

    return Container(
      color: Theme.of(context).cardColor,
      child: ListTile(
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: visible ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).disabledColor,
          ),
        ),
        trailing: Text(
          "$currency ${balance.toStringAsFixed(2)}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class CreditCardTile extends StatelessWidget {
  final String name;
  final double dueAmount;
  final double remainingCredit;
  final String currency;
  final VoidCallback? onTap;
  final bool visible;

  const CreditCardTile({
    Key? key,
    required this.name,
    required this.dueAmount,
    required this.remainingCredit,
    required this.currency,
    this.onTap,
    this.visible = true,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: ListTile(
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: visible ? Theme.of(context).textTheme.bodyLarge?.color : Theme.of(context).disabledColor,
          ),
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "next_payment".tr(),
              style: TextStyle(
                color: visible ? AppColors.gastoColor.withOpacity(0.7) : Theme.of(context).disabledColor,
                fontSize: 13,
              ),
            ),
            Text(
              "remaining_credit".tr(),
              style: TextStyle(
                color: visible ? AppColors.gastoColor.withOpacity(0.7) : Theme.of(context).disabledColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "$currency ${dueAmount.toStringAsFixed(2)}",
              style: TextStyle(
                color: visible ? AppColors.gastoColor : Theme.of(context).disabledColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              "$currency ${remainingCredit.toStringAsFixed(2)}",
              style: TextStyle(
                color: visible ? AppColors.gastoColor : Theme.of(context).disabledColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
