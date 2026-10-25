import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/screens/monthly_summary_page.dart';
import 'package:pocket_plan/services/monthly_budget_store.dart';
import 'package:pocket_plan/widgets/monthly_budget_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> enterBudget(
  WidgetTester tester,
  String text, {
  bool editing = false,
}) async {
  await tester.ensureVisible(find.text(editing ? 'Edit budget' : 'Set budget'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(editing ? 'Edit budget' : 'Set budget'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('budget-amount')), text);
  await tester.tap(find.text('Save budget'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'transactions': '[{"legacy":true}]',
    }),
  );

  test(
    'Budget parser validates decimal amounts without floating point rounding',
    () {
      expect(MonthlyBudgetStore.parseCents('123,45'), 12345);
      expect(MonthlyBudgetStore.parseCents(' 0.01 '), 1);
      expect(MonthlyBudgetStore.parseCents('10.5'), 1050);
      for (final invalid in [
        '',
        '0',
        '-1',
        'NaN',
        'Infinity',
        '1.234',
        '1e3',
        '99999999999999999999',
      ]) {
        expect(MonthlyBudgetStore.parseCents(invalid), isNull, reason: invalid);
      }
    },
  );

  test(
    'Budgets survive reload, stay separate per year/month, and preserve transactions',
    () async {
      final store = MonthlyBudgetStore();
      expect(await store.load(DateTime(2026, 10)), isNull);
      expect(await store.save(DateTime(2026, 10), 10000), isTrue);
      expect(await store.save(DateTime(2026, 11), 20000), isTrue);
      expect(await MonthlyBudgetStore().load(DateTime(2026, 10)), 10000);
      expect(await store.load(DateTime(2026, 11)), 20000);
      expect(await store.load(DateTime(2025, 10)), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), '[{"legacy":true}]');
    },
  );

  testWidgets(
    'Set, validate, cancel and edit budget; show overspending after reload',
    (tester) async {
      final month = DateTime(2026, 10);
      Widget app() => MaterialApp(
        home: Scaffold(body: MonthlyBudgetCard(month: month, expenses: 30.25)),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await enterBudget(tester, '0');
      expect(
        find.text('Enter a positive amount with up to 2 decimals.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await enterBudget(tester, '100,50');
      expect(find.text('Budget: €100.50'), findsOneWidget);
      expect(find.text('Remaining: €70.25'), findsOneWidget);
      await tester.tap(find.text('Edit budget'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('budget-amount')),
        '999',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Budget: €100.50'), findsOneWidget);
      await enterBudget(tester, '20', editing: true);
      expect(find.text('Over budget: €10.25'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Budget: €20.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Month navigation keeps budgets independent and restores previous month',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MonthlySummaryPage(
            transactions: const [],
            initialMonth: DateTime(2026, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterBudget(tester, '50');
      await tester.scrollUntilVisible(find.byTooltip('Next month'), -300);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('No budget set for this month.'));
      await enterBudget(tester, '75');
      await tester.scrollUntilVisible(find.byTooltip('Previous month'), -300);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Budget: €50.00'));
      expect(find.text('Budget: €50.00'), findsOneWidget);
      expect(find.text('Remaining: €50.00'), findsOneWidget);
    },
  );
}
