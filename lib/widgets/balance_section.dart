import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/settings_helper.dart';

class BalanceSection extends StatefulWidget {
  final double totalIncome;
  final double totalExpenses;
  final double totalBalance;
  final String title;
  final String mainCurrency;

  const BalanceSection({
    Key? key,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalBalance,
    this.title = "Balance",
    required this.mainCurrency,
  }) : super(key: key);

  @override
  State<BalanceSection> createState() => _BalanceSectionState();
}

class _BalanceSectionState extends State<BalanceSection> {
  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,##0.00", "en_US");

    return Column(
      children: [
        Divider(color: Theme.of(context).dividerColor, thickness: 1, height: 1),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildBalanceItem(
                  context,
                  "income".tr(),
                  formatter.format(widget.totalIncome),
                  widget.mainCurrency,
                  AppColors.ingresoColor,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _buildBalanceItem(
                  context,
                  "expenses".tr(),
                  formatter.format(widget.totalExpenses),
                  widget.mainCurrency,
                  AppColors.gastoColor,
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: _buildBalanceItem(
                  context,
                  "balance".tr(),
                  formatter.format(widget.totalBalance),
                  widget.mainCurrency,
                  widget.totalBalance < 0 ? AppColors.gastoColor : AppColors.ingresoColor,
                ),
              ),
            ],
          ),
        ),
        Divider(color: Theme.of(context).dividerColor, thickness: 1, height: 1),
      ],
    );
  }

  Widget _buildBalanceItem(
      BuildContext context,
      String label,
      String amount,
      String currency,
      Color color,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2), // 👈 AUMENTAMOS el espacio aquí (antes era 2)
              Text(
                currency,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
