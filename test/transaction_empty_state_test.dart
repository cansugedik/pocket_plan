import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/screens/home_page.dart';
import 'package:pocket_plan/screens/add_transaction_page.dart';
import 'package:pocket_plan/services/transaction_store.dart';
import 'package:pocket_plan/widgets/transaction_item.dart';
import 'package:pocket_plan/widgets/transaction_empty_state.dart';

const addLabel = 'Add your first transaction';
const clearLabel = 'Clear search and filters';
Future<void> reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

void size(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

String records() => jsonEncode([
  {
    'title': 'Salary',
    'category': 'Salary',
    'amount': 100,
    'isIncome': true,
    'date': '2026-10-20',
    'importId': 'id-1',
  },
  {
    'title': 'Coffee',
    'category': 'Food',
    'amount': 12.5,
    'isIncome': false,
    'date': '2026-10-10',
  },
  {
    'title': 'Bus',
    'category': 'Transport',
    'amount': 5,
    'isIncome': false,
    'date': '2026-09-10',
  },
  {'title': 'Gift', 'category': 'Other', 'amount': 8, 'isIncome': true},
]);
Future<void> choose(WidgetTester tester, int index, String value) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

class FailingStorage implements TransactionStorage {
  int writes = 0;
  @override
  Future<String?> read() async => '[]';
  @override
  Future<bool> write(String value) async {
    writes++;
    return false;
  }
}

void main() {
  testWidgets(
    'Empty action opens existing add flow; cancel does not save and explicit save persists',
    (tester) async {
      size(tester, 800, 1100);
      SharedPreferences.setMockInitialValues({
        'transactions': '[]',
        'monthly_budget_2026_10': 10000,
      });
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      await reveal(tester, addLabel);
      await tester.tap(find.text(addLabel));
      await tester.pumpAndSettle();
      expect(find.byType(AddTransactionPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), '[]');
      await reveal(tester, addLabel);
      await tester.tap(find.text(addLabel));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transaction-title')),
        'First income',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '12,50',
      );
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionEmptyState), findsNothing);
      expect(find.text('First income'), findsOneWidget);
      expect(
        (jsonDecode(prefs.getString('transactions')!) as List).single['amount'],
        12.5,
      );
      expect(prefs.getInt('monthly_budget_2026_10'), 10000);
    },
  );
  testWidgets(
    'Combined clear removes query, date, type, category and month while retaining sort and saved data',
    (tester) async {
      size(tester, 800, 1100);
      final raw = records();
      SharedPreferences.setMockInitialValues({
        'transactions': raw,
        'monthly_budget_2026_10': 10000,
      });
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('transaction-search'));
      await tester.enterText(search, 'No match');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sort by date'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<bool>, 'Oldest first'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await choose(tester, 0, 'Expense');
      await choose(tester, 1, 'Food');
      await choose(tester, 2, 'October 2026');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search by date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Clear search date'), findsOneWidget);
      expect(
        find.text('No transactions match your search and filters.'),
        findsOneWidget,
      );
      await reveal(tester, clearLabel);
      await tester.tap(find.text(clearLabel));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(find.byTooltip('Clear search date'), findsNothing);
      expect(find.text('Filters on'), findsNothing);
      expect(find.text('Clear filters'), findsNothing);
      expect(find.text('Oldest first · Undated last'), findsOneWidget);
      expect(
        tester
            .widgetList<TransactionItem>(find.byType(TransactionItem))
            .map((item) => item.title)
            .toList(),
        ['Bus', 'Coffee', 'Salary', 'Gift'],
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), raw);
      expect(prefs.getInt('monthly_budget_2026_10'), 10000);
    },
  );
  testWidgets(
    'Filter-only no results offers combined clear without changing records',
    (tester) async {
      size(tester, 800, 1100);
      final raw = records();
      SharedPreferences.setMockInitialValues({'transactions': raw});
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await choose(tester, 0, 'Income');
      await choose(tester, 1, 'Food');
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('No transactions match your filters.'), findsOneWidget);
      await reveal(tester, clearLabel);
      await tester.tap(find.text(clearLabel));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItem), findsNWidgets(4));
      expect(
        (await SharedPreferences.getInstance()).getString('transactions'),
        raw,
      );
    },
  );
  testWidgets(
    'Failed save leaves the empty-state add action disabled until reload',
    (tester) async {
      size(tester, 800, 1100);
      final storage = FailingStorage();
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(store: TransactionStore(storage: storage)),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, addLabel);
      await tester.tap(find.text(addLabel));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transaction-title')),
        'Unsaved',
      );
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '1',
      );
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();
      expect(storage.writes, 1);
      expect(find.text('Unsaved'), findsNothing);
      expect(
        tester
            .widget<TransactionEmptyState>(find.byType(TransactionEmptyState))
            .onAction,
        isNull,
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'Empty component scrolls at 200% text in a short phone viewport',
    (tester) async {
      size(tester, 320, 220);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 220),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: TransactionEmptyState(
                hasConditions: false,
                title: 'No transactions yet.',
                onAction: () => calls++,
              ),
            ),
          ),
        ),
      );
      await reveal(tester, addLabel);
      await tester.tap(find.text(addLabel));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Narrow home supports clearing search with keyboard and 200% text',
    (tester) async {
      size(tester, 320, 640);
      addTearDown(tester.view.resetViewInsets);
      SharedPreferences.setMockInitialValues({'transactions': '[]'});
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
      final search = find.byKey(const ValueKey('transaction-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'missing');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await reveal(tester, clearLabel);
      await tester.tap(find.text(clearLabel));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await reveal(tester, addLabel);
      expect(find.text(addLabel).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('transactions'),
        '[]',
      );
    },
  );
}
