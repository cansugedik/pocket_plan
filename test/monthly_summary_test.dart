import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/model/monthly_summary.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/screens/monthly_summary_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Transaction entry(String title, double amount, bool income, DateTime? date) =>
    Transaction(
      title: title,
      category: 'Other',
      amount: amount,
      icon: Icons.payments,
      isIncome: income,
      date: date,
    );

void main() {
  final records = [
    entry('Pay', 100.75, true, DateTime(2026, 1, 1)),
    entry('Food', 40.25, false, DateTime(2026, 1, 31)),
    entry('Bills', 20.10, false, DateTime(2026, 1, 10)),
    entry('December', 200, true, DateTime(2025, 12, 31)),
    entry('Other year', 900, true, DateTime(2025, 1, 1)),
    entry('Undated', 500, false, null),
  ];

  test(
    'Monthly totals include month boundaries, decimals and both types only in selected year',
    () {
      final before = records.map((t) => t.toJson()).toList();
      final result = MonthlySummary.fromTransactions(
        records,
        DateTime(2026, 1),
      );
      expect(result.income, 100.75);
      expect(result.expense, closeTo(60.35, 0.00001));
      expect(result.balance, closeTo(40.40, 0.00001));
      expect(result.transactionCount, 3);
      expect(records.map((t) => t.toJson()).toList(), before);
      final empty = MonthlySummary.fromTransactions(records, DateTime(2026, 2));
      expect(empty.balance, 0);
      expect(empty.transactionCount, 0);
      final negative = MonthlySummary.fromTransactions([
        entry('Loss', 25, false, DateTime(2026, 1, 1)),
      ], DateTime(2026, 1));
      expect(negative.balance, -25);
    },
  );

  testWidgets(
    'Month navigation crosses years and handles empty months on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlySummaryPage(
            transactions: records,
            initialMonth: DateTime(2026, 1),
          ),
        ),
      );
      expect(find.text('January 2026'), findsOneWidget);
      expect(find.text('€40.40'), findsOneWidget);
      expect(find.text('€60.35'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('December 2025'), findsOneWidget);
      expect(find.text('€200.00'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('February 2026'), findsOneWidget);
      expect(
        find.text('No dated transactions for this month.'),
        findsOneWidget,
      );
      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final context = tester.element(find.byType(MonthlySummaryPage));
      expect(
        find.text(MaterialLocalizations.of(context).formatMonthYear(now)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Summary opens from home and leaves saved records untouched', (
    tester,
  ) async {
    final stored = jsonEncode(records.map((t) => t.toJson()).toList());
    SharedPreferences.setMockInitialValues({'transactions': stored});
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Monthly summary'));
    await tester.pumpAndSettle();
    expect(find.text('Monthly balance'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pocket Plan'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('transactions'), stored);
  });
}
