import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/utils/transaction_search.dart';
import 'package:pocket_plan/utils/transaction_date_filter.dart';
import 'package:pocket_plan/widgets/transaction_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'Search matches title or category, trims spaces and handles Turkish I',
    () {
      const transaction = Transaction(
        title: 'İSTANBUL alışveriş',
        category: 'Shopping',
        amount: 10,
        icon: Icons.shopping_cart,
        isIncome: false,
      );
      for (final query in [
        '',
        '  ',
        ' istanbul ',
        'ALIŞVERİŞ',
        'SHOP',
        'ıstanbul',
      ]) {
        expect(
          matchesTransactionQuery(transaction, query),
          isTrue,
          reason: query,
        );
      }
      expect(matchesTransactionQuery(transaction, 'Salary'), isFalse);
      expect(matchesTransactionQuery(transaction, '.*'), isFalse);
    },
  );

  test(
    'Calendar search matches one day irrespective of time and excludes undated records',
    () {
      final date = DateTime(2026, 10, 10);
      expect(
        matchesTransactionDate(DateTime(2026, 10, 10, 23, 59), date),
        isTrue,
      );
      expect(matchesTransactionDate(DateTime(2025, 10, 10), date), isFalse);
      expect(matchesTransactionDate(DateTime(2026, 10, 11), date), isFalse);
      expect(matchesTransactionDate(null, date), isFalse);
      expect(matchesTransactionDate(null, null), isTrue);
    },
  );

  late String stored;
  setUp(() {
    stored = jsonEncode([
      {
        'title': 'Market October',
        'category': 'Food',
        'amount': 30,
        'isIncome': false,
        'date': '2026-10-10',
      },
      {
        'title': 'Market September',
        'category': 'Food',
        'amount': 20,
        'isIncome': false,
        'date': '2026-09-10',
      },
      {
        'title': 'Salary',
        'category': 'Income',
        'amount': 100,
        'isIncome': true,
      },
    ]);
    SharedPreferences.setMockInitialValues({'transactions': stored});
  });

  testWidgets(
    'Search combines with filters, clears independently and never saves view state',
    (tester) async {
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('transaction-search'));
      await tester.enterText(search, 'MARKET');
      await tester.pumpAndSettle();
      expect(find.text('Salary'), findsNothing);
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('October 2026').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItem), findsOneWidget);
      expect(find.text('Market October'), findsOneWidget);
      expect(find.text('€50.00'), findsNWidgets(2));
      await tester.enterText(search, 'nothing matches');
      await tester.pumpAndSettle();
      expect(
        find.text('No transactions match your search and filters.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Market October'), findsOneWidget);
      expect(find.text('Filters on'), findsOneWidget);
      await tester.enterText(search, 'food');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'food');
      expect(
        tester
            .widget<ListView>(find.byType(ListView).last)
            .childrenDelegate
            .estimatedChildCount,
        2,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), stored);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    },
  );

  testWidgets(
    'Calendar beside search combines with text, cancels safely and clears independently',
    (tester) async {
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('transaction-search'));
      await tester.enterText(search, 'Market');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search by date'));
      await tester.pumpAndSettle();
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        localizations.formatCompactDate(DateTime(2026, 10, 10)),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Market October'), findsOneWidget);
      expect(find.text('Market September'), findsNothing);
      expect(find.byTooltip('Clear search date'), findsOneWidget);
      await tester.tap(find.byTooltip('Search by date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Market October'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear search date'), findsOneWidget);
      expect(find.byType(TransactionItem), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search date'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byType(ListView).last)
            .childrenDelegate
            .estimatedChildCount,
        3,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), stored);
    },
  );

  testWidgets('Editing searched records keeps hidden transactions intact', (
    tester,
  ) async {
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'October',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Market October'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Renamed');
    await tester.ensureVisible(find.text('Update Transaction'));
    await tester.tap(find.text('Update Transaction'));
    await tester.pumpAndSettle();
    expect(
      find.text('No transactions match your search and filters.'),
      findsOneWidget,
    );
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('transactions')!) as List;
    expect(saved.map((t) => t['title']).toList(), [
      'Renamed',
      'Market September',
      'Salary',
    ]);
  });

  testWidgets('Search remains usable at phone size with keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.enterText(
      find.byKey(const ValueKey('transaction-search')),
      'market',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('transaction-search')), findsOneWidget);
  });
}
