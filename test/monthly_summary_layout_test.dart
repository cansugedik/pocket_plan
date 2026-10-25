import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/screens/monthly_summary_page.dart';
import 'package:pocket_plan/widgets/balance_card.dart';

final records = [
  Transaction(
    title: 'Pay',
    category: 'Salary',
    amount: 100.25,
    isIncome: true,
    icon: Icons.payments,
    date: DateTime(2026, 12, 1),
  ),
  Transaction(
    title: 'Expense',
    category: 'Very long imported category name',
    amount: 123456789.99,
    isIncome: false,
    icon: Icons.shopping_cart,
    date: DateTime(2026, 12, 31),
  ),
  const Transaction(
    title: 'Undated',
    category: 'Other',
    amount: 5,
    isIncome: false,
    icon: Icons.payments,
  ),
];
Future<void> reveal(WidgetTester tester, Finder target, double delta) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Wide monthly content is centered and leaves preferences untouched',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final raw = jsonEncode(records.map((t) => t.toJson()).toList());
      SharedPreferences.setMockInitialValues({
        'transactions': raw,
        'monthly_budget_2026_12': 100000,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlySummaryPage(
            transactions: records,
            initialMonth: DateTime(2026, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(BalanceCard));
      expect(rect.width, lessThanOrEqualTo(928));
      expect(rect.center.dx, closeTo(720, 1));
      expect(find.text('Monthly balance'), findsOneWidget);
      expect(find.byKey(const ValueKey('monthly-balance')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), raw);
      expect(prefs.getInt('monthly_budget_2026_12'), 100000);
    },
  );

  for (final width in [320.0, 600.0]) {
    testWidgets(
      'Large monthly amounts, charts and budget at 200% text on $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final raw = jsonEncode(records.map((t) => t.toJson()).toList());
        SharedPreferences.setMockInitialValues({
          'transactions': raw,
          'monthly_budget_2026_12': 100000,
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: MonthlySummaryPage(
              transactions: records,
              initialMonth: DateTime(2026, 12),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('€-123456689.74'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('Over budget: €123455789.99'), 200);
        final budgetBar = tester.widget<LinearProgressIndicator>(
          find.byWidgetPredicate(
            (widget) =>
                widget is LinearProgressIndicator &&
                widget.semanticsLabel == 'Monthly budget used',
          ),
        );
        expect(budgetBar.value, 1);
        expect(budgetBar.semanticsValue, '100.0%');
        expect(tester.takeException(), isNull);
        await reveal(tester, find.text('Spending by category'), 200);
        await reveal(tester, find.text('€123456789.99 · 100.0%'), 200);
        expect(find.text('Very long imported category name'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (width == 320) {
          await reveal(tester, find.text('Edit budget'), -200);
          await tester.tap(find.text('Edit budget'));
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('budget-amount')),
            '0',
          );
          await tester.tap(find.text('Save budget'));
          await tester.pumpAndSettle();
          expect(
            find.text('Enter a positive amount with up to 2 decimals.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          tester.view.resetViewInsets();
        }
        await reveal(tester, find.byTooltip('Next month'), -300);
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        expect(find.text('January 2027'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('transactions'), raw);
        expect(prefs.getInt('monthly_budget_2026_12'), 100000);
        expect(prefs.getInt('monthly_budget_2027_01'), isNull);
      },
    );
  }
  testWidgets(
    'Empty month without budget has clear empty states at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'transactions': '[]'});
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: MonthlySummaryPage(
            transactions: const [],
            initialMonth: DateTime(2026, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.text('No dated transactions for this month.'),
        200,
      );
      await reveal(tester, find.text('No budget set for this month.'), 200);
      await reveal(tester, find.text('No expenses for this month.'), 200);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), '[]');
    },
  );
}
