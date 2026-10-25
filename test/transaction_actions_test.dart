import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/screens/add_transaction_page.dart';
import 'package:pocket_plan/widgets/transaction_item.dart';

void main() {
  Future<void> load(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'transactions': jsonEncode([
        {
          'title': 'Coffee',
          'category': 'Food',
          'amount': 5,
          'isIncome': false,
          'date': '2026-10-10',
          'importId': 'preserved',
        },
        {
          'title': 'Salary',
          'category': 'Salary',
          'amount': 100,
          'isIncome': true,
        },
      ]),
      'monthly_budget_2026_10': 10000,
    });
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, String action) async {
    final button = find.byTooltip('Actions for Coffee');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('Menu edit opens existing form and preserves metadata on save', (
    tester,
  ) async {
    await load(tester);
    await menu(tester, 'Edit');
    expect(find.byType(AddTransactionPage), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('transaction-amount')),
      '7',
    );
    await tester.ensureVisible(find.text('Update Transaction'));
    await tester.tap(find.text('Update Transaction'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final records = jsonDecode(prefs.getString('transactions')!) as List;
    expect(records.length, 2);
    expect(records.first['amount'], 7);
    expect(records.first['importId'], 'preserved');
    expect(records.first['date'], startsWith('2026-10-10'));
    expect(records.last['title'], 'Salary');
    expect(prefs.getInt('monthly_budget_2026_10'), 10000);
  });
  testWidgets(
    'Menu delete requires confirmation, cancel preserves data, confirm persists',
    (tester) async {
      await load(tester);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('transactions');
      await menu(tester, 'Delete');
      expect(find.text('Delete Transaction'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(prefs.getString('transactions'), raw);
      await menu(tester, 'Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      final records = jsonDecode(prefs.getString('transactions')!) as List;
      expect(records.single['title'], 'Salary');
      expect(prefs.getInt('monthly_budget_2026_10'), 10000);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      expect(find.text('Coffee'), findsNothing);
      expect(
        tester.widget<TransactionItem>(find.byType(TransactionItem)).title,
        'Salary',
      );
    },
  );
  for (final enabled in [true, false]) {
    testWidgets('Keyboard actions and failed deletion with enabled=$enabled', (
      tester,
    ) async {
      var edits = 0;
      var deletes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionItem(
              title: 'Test',
              subtitle: 'Food',
              dateLabel: 'Date not specified',
              amount: '-€5.00',
              icon: Icons.shopping_cart,
              enabled: enabled,
              transactionKey: const ValueKey('record'),
              onTap: () => edits++,
              onDelete: () async {
                deletes++;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Actions for Test'));
      await tester.pumpAndSettle();
      if (!enabled) {
        expect(find.text('Edit'), findsNothing);
        expect(edits, 0);
        expect(deletes, 0);
        return;
      }
      Focus.of(tester.element(find.text('Edit'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(edits, 1);
      await tester.tap(find.byTooltip('Actions for Test'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.byType(TransactionItem), findsOneWidget);
    });
  }
}
