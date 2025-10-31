import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class MoneyText extends StatelessWidget {
  final String text;
  final double rawAmount;
  final bool positiveIsGood;
  final TextStyle? style;
  final Color? colorOverride;

  const MoneyText({
    super.key,
    required this.text,
    required this.rawAmount,
    this.positiveIsGood = true,
    this.style,
    this.colorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final good = rawAmount >= 0;
    final logicColor = (positiveIsGood ? good : !good)
        ? AppColors.ingresoColor
        : AppColors.gastoColor;
    final finalColor = colorOverride ?? logicColor;

    return Text(
      text,
      style: (style ?? const TextStyle(fontWeight: FontWeight.w600, fontSize: 18))
          .copyWith(color: finalColor),
    );
  }
}
