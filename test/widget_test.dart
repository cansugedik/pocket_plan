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
    expect(find.text('€120'), findsNWidgets(2));

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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    expect(find.text('Gift'), findsOneWidget);
    expect(find.text('€150'), findsNWidgets(2));
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
    });
  }
}
