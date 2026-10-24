import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/screens/add_transaction_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> selectCategory(WidgetTester tester, String category) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(category).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Categories follow type and keep shared Other selection', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddTransactionPage()));
    final dropdown = find.byType(DropdownButton<String>);
    List<String?> options() => tester
        .widget<DropdownButton<String>>(dropdown)
        .items!
        .map((item) => item.value)
        .toList();
    expect(options(), ['Salary', 'Freelance', 'Gift', 'Other']);
    await selectCategory(tester, 'Salary');
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(options(), [
      'Food',
      'Shopping',
      'Transport',
      'Bills',
      'Health',
      'Entertainment',
      'Other',
    ]);
    expect(find.text('Other'), findsOneWidget);
    await selectCategory(tester, 'Food');
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Other'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Adding and editing persist category and amount after reload', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'transactions': '[]'});
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Project payment');
    await tester.enterText(find.byType(TextField).at(1), '120');
    await selectCategory(tester, 'Freelance');
    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Freelance'), findsOneWidget);
    expect(find.text('€120.00'), findsNWidgets(2));

    await tester.tap(find.text('Project payment'));
    await tester.pumpAndSettle();
    expect(find.text('Freelance'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '150');
    await selectCategory(tester, 'Gift');
    await tester.tap(find.text('Update Transaction'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('transactions')!) as List;
    expect(saved.single['category'], 'Gift');
    expect(saved.single['amount'], 150);
    final today = DateTime.now().toIso8601String().split('T').first;
    expect(saved.single['date'], today);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    expect(find.text('Gift'), findsOneWidget);
    expect(find.text('€150.00'), findsNWidgets(2));
  });

  test('Date-only JSON round trip and old records remain compatible', () {
    final original = Transaction(
      title: 'Dated',
      category: 'Food',
      amount: 10,
      icon: Icons.shopping_cart,
      isIncome: false,
      date: DateTime(2026, 10, 15),
    );
    expect(original.toJson()['date'], '2026-10-15');
    expect(
      Transaction.fromJson(original.toJson()).date,
      DateTime(2026, 10, 15),
    );
    final legacy = Map<String, dynamic>.from(original.toJson())..remove('date');
    expect(Transaction.fromJson(legacy).date, isNull);
  });

  testWidgets('Date picker edits and persists a legacy transaction date', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'transactions': jsonEncode([
        {
          'title': 'Old dated record',
          'category': 'Food',
          'amount': 10,
          'isIncome': false,
        },
      ]),
    });
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old dated record'));
    await tester.pumpAndSettle();
    expect(find.text('Date: Not specified'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transaction-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Date: Not specified'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transaction-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Update Transaction'));
    await tester.tap(find.text('Update Transaction'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('transactions')!) as List;
    expect(
      saved.single['date'],
      DateTime.now().toIso8601String().split('T').first,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    expect(find.text('Date not specified'), findsNothing);
    await tester.tap(find.text('Old dated record'));
    await tester.pumpAndSettle();
    expect(find.text('Date: Not specified'), findsNothing);
  });

  for (final category in ['Income', 'Expense', 'Travel']) {
    testWidgets('Legacy $category survives editing and cancellation', (
      tester,
    ) async {
      final transaction = Transaction(
        title: 'Old record',
        category: category,
        amount: 20,
        icon: Icons.shopping_cart,
        isIncome: category == 'Income',
      );
      SharedPreferences.setMockInitialValues({
        'transactions': jsonEncode([transaction.toJson()]),
      });
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old record'));
      await tester.pumpAndSettle();
      expect(find.text(category), findsWidgets);
      await tester.enterText(find.byType(TextField).at(0), 'Discarded');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Old record'), findsOneWidget);
      await tester.tap(find.text('Old record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Transaction'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('transactions')!) as List;
      expect(saved.single['category'], category);
      expect(saved.single['title'], 'Old record');
      expect(saved.single.containsKey('date'), isFalse);
      expect(find.text('Date not specified'), findsOneWidget);
    });
  }
}
