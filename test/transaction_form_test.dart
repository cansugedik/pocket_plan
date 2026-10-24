import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/screens/add_transaction_page.dart';

const titleKey = ValueKey('transaction-title');
const amountKey = ValueKey('transaction-amount');

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Transaction'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save Transaction'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Invalid values have field errors that clear as corrected', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddTransactionPage()));
    await save(tester);
    expect(
      tester.widget<TextField>(find.byKey(titleKey)).decoration!.errorText,
      'Enter a title.',
    );
    expect(
      tester.widget<TextField>(find.byKey(amountKey)).decoration!.errorText,
      'Enter an amount greater than zero.',
    );
    expect(
      tester.widget<TextField>(find.byKey(titleKey)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byKey(titleKey), 'Lunch');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(titleKey)).decoration!.errorText,
      isNull,
    );
    for (final value in ['', '0', '-1', 'NaN', 'Infinity', 'abc']) {
      await tester.enterText(find.byKey(amountKey), value);
      await save(tester);
      expect(
        tester.widget<TextField>(find.byKey(amountKey)).decoration!.errorText,
        isNotNull,
      );
    }
    await tester.enterText(find.byKey(amountKey), '12,50');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(amountKey)).decoration!.errorText,
      isNull,
    );
    expect(find.text('Amount (EUR)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final example in [('12,50', 12.5), ('1.234', 1.234), ('1e2', 100.0)]) {
    testWidgets(
      'Existing amount acceptance and returned fields remain compatible: ${example.$1}',
      (tester) async {
        Object? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddTransactionPage(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(titleKey), '  Lunch  ');
        await tester.enterText(find.byKey(amountKey), example.$1);
        await tester.ensureVisible(find.text('Expense'));
        await tester.tap(find.text('Expense'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Expense'))
              .selected,
          isTrue,
        );
        if (example.$1 == '1e2') {
          await tester.showKeyboard(find.byKey(amountKey));
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(result, isNull);
          expect(find.byType(AddTransactionPage), findsOneWidget);
        }
        await save(tester);
        final record = result as Map;
        expect(record['title'], 'Lunch');
        expect(record['amount'], example.$2);
        expect(record['isIncome'], isFalse);
        expect(record['category'], 'Other');
        final today = DateTime.now();
        expect(record['date'], DateTime(today.year, today.month, today.day));
      },
    );
  }

  testWidgets('Wide form is centered and bounded', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AddTransactionPage()));
    final field = tester.getRect(find.byKey(titleKey));
    expect(field.width, lessThanOrEqualTo(552));
    expect(field.center.dx, closeTo(720, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Narrow form handles 200% text, legacy category and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    const original = Transaction(
      title: 'Saved',
      category: 'Long legacy category name',
      amount: 12.50,
      isIncome: false,
      icon: Icons.shopping_cart,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const AddTransactionPage(transaction: original),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Date: Not specified'), findsOneWidget);
    expect(find.text('Long legacy category name'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(titleKey));
    await tester.enterText(find.byKey(titleKey), 'Edited');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byKey(amountKey)).focusNode!.hasFocus,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('Update Transaction'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Update Transaction').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(original.title, 'Saved');
    expect(original.category, 'Long legacy category name');
    expect(original.date, isNull);
  });
}
