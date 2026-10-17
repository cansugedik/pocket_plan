import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/model/monthly_summary.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/screens/monthly_summary_page.dart';
import 'package:pocket_plan/widgets/category_spending_chart.dart';

Transaction expense(
  String category,
  double amount,
  DateTime? date, {
  bool income = false,
}) => Transaction(
  title: category,
  category: category,
  amount: amount,
  icon: Icons.payments,
  isIncome: income,
  date: date,
);

void main() {
  final month = DateTime(2026, 10);
  final records = [
    expense('Food', 10.25, month),
    expense('Food', 9.75, DateTime(2026, 10, 31)),
    expense('Travel', 60, month),
    expense('Salary', 1000, month, income: true),
    expense('Food', 500, null),
    expense('Food', 900, DateTime(2025, 10)),
    expense('Bills', 30, DateTime(2026, 9)),
  ];

  test(
    'Category sums reconcile with expenses and exclude income, other dates and undated records',
    () {
      final summary = MonthlySummary.fromTransactions(records, month);
      expect(summary.expenseByCategory, {'Food': 20, 'Travel': 60});
      expect(
        summary.expenseByCategory.values.reduce((a, b) => a + b),
        summary.expense,
      );
      expect(
        () => summary.expenseByCategory['Food'] = 99,
        throwsUnsupportedError,
      );
      expect(records.first.amount, 10.25);
    },
  );

  testWidgets(
    'Chart shows descending categories, amounts, percentages and accessible bars',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategorySpendingChart(
              summary: MonthlySummary.fromTransactions(records, month),
            ),
          ),
        ),
      );
      expect(find.text('€60.00 · 75.0%'), findsOneWidget);
      expect(find.text('€20.00 · 25.0%'), findsOneWidget);
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars.map((bar) => bar.value).toList(), [0.75, 0.25]);
      expect(bars.first.semanticsLabel, 'Travel spending');
      expect(bars.first.semanticsValue, '75.0%');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Month navigation updates chart; empty and income-only months have no bars',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlySummaryPage(transactions: records, initialMonth: month),
        ),
      );
      await tester.ensureVisible(find.text('Spending by category'));
      expect(find.text('€60.00 · 75.0%'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Previous month'));
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Spending by category'));
      expect(find.text('€30.00 · 100.0%'), findsOneWidget);
      expect(find.text('Travel'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Next month'));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Spending by category'));
      expect(find.text('No expenses for this month.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategorySpendingChart(
              summary: MonthlySummary.fromTransactions([
                expense('Salary', 100, month, income: true),
              ], month),
            ),
          ),
        ),
      );
      expect(find.text('No expenses for this month.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}
