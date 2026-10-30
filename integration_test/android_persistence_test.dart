import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/services/monthly_budget_store.dart';
import 'package:pocket_plan/services/transaction_store.dart';
import 'package:pocket_plan/widgets/balance_card.dart';

const tokenKey = 'pocket_plan_disposable_test_token';
const stageKey = 'pocket_plan_disposable_test_stage';
const token = String.fromEnvironment('POCKET_PLAN_TEST_TOKEN');
const phase = String.fromEnvironment('POCKET_PLAN_TEST_PHASE');
const expenseTitle = 'Persistence test expense';
const incomeTitle = 'Persistence test income';
final month = DateTime(2026, 10);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Android persistence phase: $phase', (tester) async {
    // Run only through tool/test_android_persistence.py, which creates a fresh
    // AVD. Never clear preferences or seed an existing application data set.
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('POCKET_PLAN_DISPOSABLE_TEST'), isTrue);
    expect(token, isNotEmpty);
    expect(['seed', 'edit', 'delete', 'verify'].contains(phase), isTrue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (phase == 'seed') {
      expect(
        prefs.getKeys(),
        isEmpty,
        reason: 'Refuse to seed nonempty storage',
      );
    } else {
      expect(
        prefs.getString(tokenKey),
        token,
        reason: 'Refuse unknown storage',
      );
      final expectedStage = {
        'edit': 'seed',
        'delete': 'edited',
        'verify': 'deleted',
      }[phase];
      expect(prefs.getString(stageKey), expectedStage);
    }
    final store = TransactionStore();
    final budgets = MonthlyBudgetStore();
    if (phase == 'seed') {
      expect(await store.load(initialTransactions: []), isEmpty);
      expect(
        await store.save([
          Transaction(
            title: expenseTitle,
            category: 'Food',
            amount: 20,
            icon: Icons.shopping_cart,
            isIncome: false,
            date: DateTime(2026, 10, 15),
            importId: 'persistence-expense-id',
          ),
          Transaction(
            title: incomeTitle,
            category: 'Salary',
            amount: 100,
            icon: Icons.account_balance_wallet,
            isIncome: true,
            date: DateTime(2026, 10, 14),
            importId: 'persistence-income-id',
          ),
        ]),
        isTrue,
      );
      expect(await budgets.save(month, 15000), isTrue);
      expect(await prefs.setString(tokenKey, token), isTrue);
      expect(await prefs.setString(stageKey, 'seed'), isTrue);
    }
    final records = await store.load(initialTransactions: []);
    expect(await budgets.load(month), 15000);
    final income = records.singleWhere((t) => t.isIncome);
    expect(income.title, incomeTitle);
    expect(income.amount, 100);
    expect(income.category, 'Salary');
    expect(income.date, DateTime(2026, 10, 14));
    expect(income.importId, 'persistence-income-id');
    if (phase == 'verify') {
      expect(records.length, 1);
    } else {
      expect(records.length, 2);
      final expense = records.singleWhere((t) => !t.isIncome);
      expect(expense.title, expenseTitle);
      expect(expense.amount, phase == 'delete' ? 25 : 20);
      expect(expense.category, 'Food');
      expect(expense.date, DateTime(2026, 10, 15));
      expect(expense.importId, 'persistence-expense-id');
    }
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    expect(
      tester.widget<BalanceCard>(find.byType(BalanceCard)).balance,
      phase == 'verify'
          ? 100
          : phase == 'delete'
          ? 75
          : 80,
    );
    if (phase == 'edit' || phase == 'delete') {
      final action = find.byTooltip('Actions for $expenseTitle');
      await tester.scrollUntilVisible(
        action,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text(phase == 'edit' ? 'Edit' : 'Delete'));
      await tester.pumpAndSettle();
      if (phase == 'edit') {
        await tester.enterText(
          find.byKey(const ValueKey('transaction-amount')),
          '25',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Update Transaction'));
        await tester.tap(find.text('Update Transaction'));
      } else {
        await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      }
      await tester.pumpAndSettle();
      final saved = await TransactionStore().load(initialTransactions: []);
      expect(saved.length, phase == 'edit' ? 2 : 1);
      if (phase == 'edit') {
        expect(saved.singleWhere((t) => !t.isIncome).amount, 25);
      }
      expect(
        await prefs.setString(stageKey, phase == 'edit' ? 'edited' : 'deleted'),
        isTrue,
      );
    }
    expect(await budgets.load(month), 15000);
    expect(tester.takeException(), isNull);
    // The host runner requires this exact marker before progressing to the
    // next process, so reseeding or an unsuccessful phase cannot look like a pass.
    debugPrint('POCKET_PLAN_PERSISTENCE_OK:$phase');
  });
}
