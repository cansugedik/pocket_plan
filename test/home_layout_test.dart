import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/screens/home_page.dart';
import 'package:pocket_plan/widgets/balance_card.dart';
import 'package:pocket_plan/widgets/transaction_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Wide home content is centered and bounded without saving data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'transactions': '[]'});
    await tester.pumpWidget(const PocketPlanApp());
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byType(BalanceCard));
    expect(card.width, lessThanOrEqualTo(928));
    expect(card.center.dx, closeTo(720, 1));
    expect(find.byTooltip('Add transaction'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('transactions'), '[]');
  });

  for (final width in [320.0, 600.0]) {
    testWidgets(
      'Large balance and summary remain readable at width $width with 200% text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(2),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: BalanceCard(
                      balance: -123456789.99,
                      income: 123456789.99,
                      expense: 246913579.98,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('€-123456789.99'), findsOneWidget);
        expect(find.text('Income'), findsOneWidget);
        expect(find.text('Expenses'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final paragraph = tester.widget<Text>(find.text('€-123456789.99'));
        expect(paragraph.maxLines, isNull);
        expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
      },
    );
  }

  testWidgets('Large transaction amount fits a phone with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TransactionItem(
                title: 'Long saved transaction title',
                subtitle: 'Entertainment',
                dateLabel: 'Date not specified',
                amount: '-€123456789.99',
                icon: Icons.shopping_cart,
                onDelete: () async => false,
                onTap: () {},
                transactionKey: const ValueKey('large'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('-€123456789.99'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Phone home supports large text, search and filters without changing records',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final raw = jsonEncode([
        {
          'title': 'Saved expense',
          'category': 'Food',
          'amount': 12.50,
          'isIncome': false,
          'date': '2026-10-24',
        },
      ]);
      SharedPreferences.setMockInitialValues({'transactions': raw});
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const HomePage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final search = find.byKey(const ValueKey('transaction-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Food');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Filter transactions'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), raw);
    },
  );
}
