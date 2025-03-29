// This is a basic Flutter widgets test.
//
// To perform an interaction with a widgets in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widgets
// tree, read text, and verify that the values of widgets properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashflowx/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Crear datos de prueba para cuentas, transacciones y categorías
    List<Map<String, dynamic>> testAccounts = [];
    List<Map<String, dynamic>> testTransactions = [];
    List<Map<String, dynamic>> testCategories = [];

    await tester.pumpWidget(MyApp(
      accounts: testAccounts,
      transactions: testTransactions,
      categories: testCategories,
    ));
  });
}

