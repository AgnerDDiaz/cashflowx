// Este archivo contendrá los widgets reutilizables de la pantalla de cuentas.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final color = totalBalance >= 0 ? Colors.blue : Colors.red;
    final textColor = isHidden ? Colors.grey : color;

    return Container(
      color: Colors.grey[200],
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
      color = Colors.grey;
    } else if (balance >= 0) {
      color = Colors.green;
    } else {
      color = Colors.red;
    }

    return ListTile(
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: visible ? Colors.black : Colors.grey,
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

    return ListTile(
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: visible ? Colors.black : Colors.grey,
        ),
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Pago próximo",
            style: TextStyle(
              color: visible ? Colors.red[400] : Colors.grey,
              fontSize: 13,
            ),
          ),
          Text(
            "Crédito restante",
            style: TextStyle(
              color: visible ? Colors.red[400] : Colors.grey,
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
              color: visible ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            formatter.format(remainingCredit),
            style: TextStyle(
              color: visible ? Colors.red : Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
