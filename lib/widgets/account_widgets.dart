// Este archivo contendrá los widgets reutilizables de la pantalla de cuentas.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';

class AccountCategoryHeader extends StatelessWidget {
  final String category;
  final double totalBalance;
  final bool isHidden;

  const AccountCategoryHeader({
    super.key,
    required this.category,
    required this.totalBalance,
    this.isHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final color = totalBalance >= 0 ? AppColors.ingresoColor : AppColors.gastoColor;
    final textColor = isHidden ? Theme.of(context).disabledColor : color;

    final backgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Theme.of(context).cardColor;

    return Container(
      color: backgroundColor,
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
            height: 12,
            thickness: 12,
            indent: 0,
            endIndent: 0,
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
    super.key,
    required this.name,
    required this.balance,
    required this.currency,
    this.visible = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: currency);
    Color color;

    if (!visible) {
      color = Theme.of(context).disabledColor;
    } else if (balance >= 0) {
      color = AppColors.ingresoColor;
    } else {
      color = AppColors.gastoColor;
    }

    final backgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Theme.of(context).cardColor;

    return Container(
      color: backgroundColor,
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
          formatter.format(balance),
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
    super.key,
    required this.name,
    required this.dueAmount,
    required this.remainingCredit,
    required this.currency,
    this.onTap,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: currency);

    final backgroundColor = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Theme.of(context).cardColor;

    return Container(
      color: backgroundColor,
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
              formatter.format(dueAmount),
              style: TextStyle(
                color: visible ? AppColors.gastoColor : Theme.of(context).disabledColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              formatter.format(remainingCredit),
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
