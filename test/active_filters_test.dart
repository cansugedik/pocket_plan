import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_filters_test.dart' as filters;

const scope =
    'Search and filters affect the list. Balance shows all transactions.';
void main() {
  Future<String> load(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final raw = jsonEncode([
      {
        'title': 'Coffee',
        'category': 'Food',
        'amount': 5,
        'isIncome': false,
        'date': '2026-10-10',
        'importId': 'id-1',
      },
      {
        'title': 'Meal',
        'category': 'Food',
        'amount': 10,
        'isIncome': false,
        'date': '2026-09-10',
      },
      {'title': 'Pay', 'category': 'Salary', 'amount': 100, 'isIncome': true},
    ]);
    SharedPreferences.setMockInitialValues({
      'transactions': raw,
      'monthly_budget_2026_10': 10000,
    });
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    return raw;
  }

  testWidgets(
    'Filter chips clear independently and result count reflects retained search',
    (tester) async {
      final raw = await load(tester);
      await tester.enterText(
        find.byKey(const ValueKey('transaction-search')),
        'Coffee',
      );
      await tester.pumpAndSettle();
      expect(find.text(scope), findsOneWidget);
      expect(find.text('1 of 3 transactions'), findsOneWidget);
      await filters.openFilters(tester);
      await filters.choose(tester, 0, 'Expense');
      await filters.choose(tester, 1, 'Food');
      await filters.choose(tester, 2, 'October 2026');
      await filters.applyFilters(tester);
      expect(find.text('Type: Expense'), findsOneWidget);
      expect(find.text('Category: Food'), findsOneWidget);
      expect(find.text('Month: October 2026'), findsOneWidget);
      for (final tooltip in [
        'Clear type filter',
        'Clear category filter',
        'Clear month filter',
      ]) {
        await tester.ensureVisible(find.byTooltip(tooltip));
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        expect(find.byTooltip(tooltip), findsNothing);
        expect(find.text('1 of 3 transactions'), findsOneWidget);
      }
      expect(find.text('Filters on'), findsNothing);
      expect(find.text(scope), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 transactions'), findsOneWidget);
      expect(find.text(scope), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), raw);
      expect(prefs.getInt('monthly_budget_2026_10'), 10000);
    },
  );
  testWidgets(
    'Date-only scope and undated month chip update counts without saving',
    (tester) async {
      final raw = await load(tester);
      await tester.tap(find.byTooltip('Search by date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text(scope), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search date'));
      await tester.pumpAndSettle();
      expect(find.text(scope), findsNothing);
      await filters.openFilters(tester);
      await filters.choose(tester, 2, 'Date not specified');
      await filters.applyFilters(tester);
      expect(find.text('Month: Date not specified'), findsOneWidget);
      expect(find.text('1 of 3 transactions'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear month filter'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3 transactions'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString('transactions'),
        raw,
      );
    },
  );
  testWidgets('Active chips remain removable on a 320px screen at 200% text', (
    tester,
  ) async {
    final raw = await load(tester);
    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filters'));
    await tester.pumpAndSettle();
    await filters.openFilters(tester);
    await filters.choose(tester, 0, 'Expense');
    await filters.choose(tester, 1, 'Food');
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.pumpAndSettle();
    await filters.applyFilters(tester);
    for (final tooltip in ['Clear type filter', 'Clear category filter']) {
      await tester.ensureVisible(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(find.byTooltip(tooltip), findsNothing);
    }

    expect(
      (await SharedPreferences.getInstance()).getString('transactions'),
      raw,
    );
  });
}
