import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 📌 Para formatear números con separador de miles

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
    final formatter = NumberFormat("#,##0.00", "en_US"); // 📌 Formato de moneda

    return Column(
      children: [
        const Divider(color: Colors.grey, thickness: 1, height: 1),

        Container(

          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title, // 📌 Título dinámico
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBalanceItem("Ingreso", formatter.format(totalIncome), Colors.green),
                  _buildBalanceItem("Gastos", formatter.format(totalExpenses), Colors.red),
                  _buildBalanceItem(
                    "Balance",
                    formatter.format(totalBalance),
                    totalBalance < 0 ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),

        // 🔹 Línea divisoria inferior
        const Divider(color: Colors.grey, thickness: 1, height: 1),
      ],
    );
  }

  /// 🔹 Método auxiliar para construir cada sección (Ingreso, Gastos, Balance)
  Widget _buildBalanceItem(String label, String amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
