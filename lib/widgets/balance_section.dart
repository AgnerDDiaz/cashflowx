import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart'; // 👈 Importante

class BalanceSection extends StatelessWidget {
  final double totalIncome;
  final double totalExpenses;
  final double totalBalance;
  final String title;

  const BalanceSection({
    Key? key,
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalBalance,
    this.title = "Balance",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,##0.00", "en_US");

    return Column(
      children: [
        Divider(color: Theme.of(context).dividerColor, thickness: 1, height: 1),

        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBalanceItem(context, "income".tr(), formatter.format(totalIncome), AppColors.ingresoColor),
                  _buildBalanceItem(context, "expenses".tr(), formatter.format(totalExpenses), AppColors.gastoColor),
                  _buildBalanceItem(
                    context,
                    "balance".tr(),
                    formatter.format(totalBalance),
                    totalBalance < 0 ? AppColors.gastoColor : AppColors.ingresoColor,
                  ),
                ],
              ),
            ],
          ),
        ),

        Divider(color: Theme.of(context).dividerColor, thickness: 1, height: 1),
      ],
    );
  }

  /// Método auxiliar corregido
  Widget _buildBalanceItem(BuildContext context, String label, String amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).hintColor, // 👈 Dinámico
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
