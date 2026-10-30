import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/widgets/balance_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Isolated native smoke: menu, search, edit, delete and financial totals',
    (tester) async {
      // This overrides the storage channel before the app starts. No real native
      // preferences are read, cleared or written by this test.
      SharedPreferences.setMockInitialValues({
        'transactions': jsonEncode([
          {
            'title': 'Test Coffee',
            'category': 'Food',
            'amount': 20,
            'isIncome': false,
            'date': '2026-10-30',
            'importId': 'test-id',
          },
          {
            'title': 'Test Salary',
            'category': 'Salary',
            'amount': 100,
            'isIncome': true,
            'date': '2026-10-30',
          },
        ]),
        'monthly_budget_2026_10': 10000,
      });
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).balance, 80);
      await tester.tap(find.byTooltip('App menu'));
      await tester.pumpAndSettle();
      for (final label in [
        'Backup & restore',
        'Import CSV',
        'Monthly summary',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Monthly summary'));
      await tester.pumpAndSettle();
      expect(find.text('Monthly balance'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('transaction-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Test Coffee');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('1 of 2 transactions'), findsOneWidget);
      Future<void> action(String label) async {
        final menu = find.byTooltip('Actions for Test Coffee');
        await tester.scrollUntilVisible(
          menu,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await action('Edit');
      await tester.enterText(
        find.byKey(const ValueKey('transaction-amount')),
        '25',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Update Transaction'));
      await tester.tap(find.text('Update Transaction'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final edited = jsonDecode(prefs.getString('transactions')!) as List;
      expect(edited.first['amount'], 25);
      expect(edited.first['importId'], 'test-id');
      expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).balance, 75);
      await action('Delete');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((jsonDecode(prefs.getString('transactions')!) as List).length, 2);
      await action('Delete');
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      final saved = jsonDecode(prefs.getString('transactions')!) as List;
      expect(saved.single['title'], 'Test Salary');
      expect(prefs.getInt('monthly_budget_2026_10'), 10000);
      // Scroll the header back into view after the item has been removed.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).balance, 100);
      expect(tester.takeException(), isNull);
    },
  );
}
