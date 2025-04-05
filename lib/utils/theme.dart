import 'package:flutter/material.dart';
import 'app_colors.dart'; // Asegúrate de importar tus colores

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.backgroundLight,
  fontFamily: 'Inter',
  cardColor: AppColors.cardLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundLight,
    foregroundColor: AppColors.textLight,
    elevation: 0,
    iconTheme: IconThemeData(color: AppColors.textLight),
    titleTextStyle: TextStyle(
      color: AppColors.textLight,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.textLight, fontSize: 16),
    bodyMedium: TextStyle(color: AppColors.textLight, fontSize: 14),
    titleLarge: TextStyle(color: AppColors.textLight, fontSize: 20, fontWeight: FontWeight.bold),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryColor,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.primaryColor,
  scaffoldBackgroundColor: AppColors.backgroundDark,
  fontFamily: 'Inter',
  cardColor: AppColors.cardDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.backgroundDark,
    foregroundColor: AppColors.textDark,
    elevation: 0,
    iconTheme: IconThemeData(color: AppColors.textDark),
    titleTextStyle: TextStyle(
      color: AppColors.textDark,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.textDark, fontSize: 16),
    bodyMedium: TextStyle(color: AppColors.textDark, fontSize: 14),
    titleLarge: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.bold),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.primaryColor,
  ),
);
