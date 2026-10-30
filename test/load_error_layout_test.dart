import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/screens/home_page.dart';
import 'package:pocket_plan/services/transaction_store.dart';
import 'package:pocket_plan/widgets/balance_card.dart';
import 'transaction_store_test.dart' as fixtures;

class DelayedStorage extends fixtures.MemoryStorage {
  final ready = Completer<String?>();
  DelayedStorage() : super('[]');
  @override
  Future<String?> read() => ready.future;
}

void main() {
  Future<MenuItemButton> summary(WidgetTester tester) async {
    await tester.tap(find.byTooltip('App menu'));
    await tester.pump(const Duration(milliseconds: 300));
    final item = tester.widget<MenuItemButton>(
      find.widgetWithText(MenuItemButton, 'Monthly summary'),
    );
    await tester.tap(find.byTooltip('App menu'));
    await tester.pump(const Duration(milliseconds: 300));
    return item;
  }

  for (final readFailure in [false, true]) {
    testWidgets(
      'Error and retry preserve data; narrow large text, read failure=$readFailure',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = fixtures.MemoryStorage(
          readFailure ? fixtures.encode([fixtures.old]) : 'broken',
        )..failRead = readFailure;
        final original = storage.value;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: HomePage(store: TransactionStore(storage: storage)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Unable to load transactions'), findsOneWidget);
        expect(find.byType(BalanceCard), findsNothing);
        expect((await summary(tester)).onPressed, isNull);
        expect(storage.writes, 0);
        await tester.scrollUntilVisible(
          find.text('Retry loading'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Retry loading'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retry loading'));
        await tester.pumpAndSettle();
        expect((await summary(tester)).onPressed, isNull);
        expect(storage.value, original);
        expect(storage.writes, 0);
        storage.failRead = false;
        storage.value = fixtures.encode([fixtures.old]);
        await tester.tap(find.text('Retry loading'));
        await tester.pumpAndSettle();
        expect(find.text('Unable to load transactions'), findsNothing);
        expect(find.byType(BalanceCard), findsOneWidget);
        expect((await summary(tester)).onPressed, isNotNull);
        expect(storage.value, fixtures.encode([fixtures.old]));
        expect(storage.writes, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Summary is disabled while loading and enabled after successful load',
    (tester) async {
      final storage = DelayedStorage();
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(store: TransactionStore(storage: storage)),
        ),
      );
      await tester.pump();
      expect((await summary(tester)).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      storage.ready.complete('[]');
      await tester.pumpAndSettle();
      expect((await summary(tester)).onPressed, isNotNull);
      expect(storage.writes, 0);
    },
  );
}
