import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final example in [
    (income: 12.5, expense: 0.25, balance: '€12.25'),
    (income: 10.0, expense: 12.5, balance: '€-2.50'),
    (income: 0.01, expense: 0.01, balance: '€0.00'),
  ]) {
    testWidgets(
      'Cents stay visible without rewriting records: ${example.balance}',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final records = jsonEncode([
          {
            'title': 'Test income',
            'category': 'Salary',
            'amount': example.income,
            'isIncome': true,
            'date': '2026-10-24',
            'importId': 'income-id',
          },
          {
            'title': 'Test expense',
            'category': 'Food',
            'amount': example.expense,
            'isIncome': false,
            'date': '2026-10-23',
            'importId': 'expense-id',
          },
        ]);
        SharedPreferences.setMockInitialValues({'transactions': records});
        for (var load = 0; load < 2; load++) {
          await tester.pumpWidget(const PocketPlanApp());
          await tester.pumpAndSettle();
          expect(find.text(example.balance), findsWidgets);
          expect(
            find.text('+€${example.income.toStringAsFixed(2)}'),
            findsOneWidget,
          );
          expect(
            find.text('-€${example.expense.toStringAsFixed(2)}'),
            findsOneWidget,
          );
          expect(
            find.text('€${example.income.toStringAsFixed(2)}'),
            findsWidgets,
          );
          expect(
            find.text('€${example.expense.toStringAsFixed(2)}'),
            findsWidgets,
          );
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('transactions'), records);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }
  testWidgets('Empty account displays two decimal places for all totals', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'transactions': '[]'});
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    expect(find.text('€0.00'), findsNWidgets(3));
  });
}
