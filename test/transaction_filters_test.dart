import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/widgets/transaction_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> choose(WidgetTester tester, int field, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.filter_list));
  await tester.pumpAndSettle();
}

Future<void> applyFilters(WidgetTester tester) async {
  await tester.tap(find.text('Apply filters'));
  await tester.pumpAndSettle();
}

void main() {
  late String original;
  setUp(() {
    original = jsonEncode([
      {
        'title': 'Pay',
        'category': 'Salary',
        'amount': 1000,
        'isIncome': true,
        'date': '2026-10-15',
      },
      {
        'title': 'September meal',
        'category': 'Food',
        'amount': 20,
        'isIncome': false,
        'date': '2026-09-15',
      },
      {
        'title': 'October meal',
        'category': 'Food',
        'amount': 30,
        'isIncome': false,
        'date': '2026-10-15',
      },
      {
        'title': 'Old trip',
        'category': 'Travel',
        'amount': 10,
        'isIncome': false,
      },
    ]);
    SharedPreferences.setMockInitialValues({'transactions': original});
  });

  testWidgets(
    'Date ordering works with year-specific month filters and preserves storage',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = jsonDecode(original) as List;
      records.add({
        'title': 'Last year',
        'category': 'Food',
        'amount': 5,
        'isIncome': false,
        'date': '2025-10-15',
      });
      final stored = jsonEncode(records);
      SharedPreferences.setMockInitialValues({'transactions': stored});
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      List<String> titles() => tester
          .widgetList<TransactionItem>(find.byType(TransactionItem))
          .map((item) => item.title)
          .toList();
      expect(titles(), [
        'Pay',
        'October meal',
        'September meal',
        'Last year',
        'Old trip',
      ]);
      await tester.tap(find.byTooltip('Sort by date'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<bool> && widget.value == true,
        ),
      );
      await tester.pumpAndSettle();
      expect(titles(), [
        'Last year',
        'September meal',
        'Pay',
        'October meal',
        'Old trip',
      ]);
      await openFilters(tester);
      await choose(tester, 2, 'October 2026');
      await applyFilters(tester);
      expect(titles(), ['Pay', 'October meal']);
      await openFilters(tester);
      await choose(tester, 2, 'October 2025');
      await applyFilters(tester);
      expect(titles(), ['Last year']);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(titles(), [
        'Last year',
        'September meal',
        'Pay',
        'October meal',
        'Old trip',
      ]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), stored);
    },
  );

  testWidgets(
    'Combined filters, empty results, reset and cancellation do not change storage',
    (tester) async {
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      await openFilters(tester);
      await choose(tester, 0, 'Expense');
      await choose(tester, 1, 'Food');
      await choose(tester, 2, 'October 2026');
      await applyFilters(tester);
      expect(find.byType(TransactionItem), findsOneWidget);
      expect(find.text('October meal'), findsOneWidget);
      expect(find.text('€940'), findsOneWidget);
      await openFilters(tester);
      await choose(tester, 0, 'Income');
      await applyFilters(tester);
      expect(find.text('No transactions match your filters.'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byType(ListView).last)
            .childrenDelegate
            .estimatedChildCount,
        4,
      );
      await openFilters(tester);
      await choose(tester, 0, 'Income');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byType(ListView).last)
            .childrenDelegate
            .estimatedChildCount,
        4,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), original);
    },
  );

  testWidgets('Undated legacy records remain selectable; reset restores all', (
    tester,
  ) async {
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    await openFilters(tester);
    await choose(tester, 1, 'Travel');
    await choose(tester, 2, 'Date not specified');
    await applyFilters(tester);
    expect(find.byType(TransactionItem), findsOneWidget);
    expect(find.text('Old trip'), findsOneWidget);
    await openFilters(tester);
    await tester.tap(find.text('Reset filters'));
    await tester.pumpAndSettle();
    await applyFilters(tester);
    expect(
      tester
          .widget<ListView>(find.byType(ListView).last)
          .childrenDelegate
          .estimatedChildCount,
      4,
    );
  });

  testWidgets('Editing and deleting filtered records preserve hidden records', (
    tester,
  ) async {
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    await openFilters(tester);
    await choose(tester, 1, 'Food');
    await choose(tester, 2, 'October 2026');
    await applyFilters(tester);
    await tester.tap(find.text('October meal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated meal');
    await tester.ensureVisible(find.text('Update Transaction'));
    await tester.tap(find.text('Update Transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Updated meal'), findsOneWidget);
    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions match your filters.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('transactions')!) as List;
    expect(saved.map((t) => t['title']).toList(), [
      'Pay',
      'September meal',
      'Old trip',
    ]);
  });
}
