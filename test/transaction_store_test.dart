import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/screens/home_page.dart';
import 'package:pocket_plan/services/transaction_store.dart';

class MemoryStorage implements TransactionStorage {
  String? value;
  bool failWrite = false;
  bool throwWrite = false;
  bool failRead = false;
  int writes = 0;
  MemoryStorage(this.value);
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('Read failed');
    return value;
  }

  @override
  Future<bool> write(String next) async {
    writes++;
    if (throwWrite) throw StateError('Write failed');
    if (failWrite) return false;
    value = next;
    return true;
  }
}

const old = Transaction(
  title: 'Saved transaction',
  category: 'Food',
  amount: 20,
  icon: Icons.shopping_cart,
  isIncome: false,
);
String encode(List<Transaction> transactions) =>
    jsonEncode(transactions.map((t) => t.toJson()).toList());

void main() {
  test('Corrupt load never writes defaults and blocks later saves', () async {
    final storage = MemoryStorage('{invalid json');
    final store = TransactionStore(storage: storage);
    await expectLater(
      store.load(initialTransactions: [old]),
      throwsFormatException,
    );
    expect(await store.save([]), isFalse);
    expect(storage.value, '{invalid json');
    expect(storage.writes, 0);
  });

  test('Read/initial write failures block saving; retry can recover', () async {
    final storage = MemoryStorage(null)..failRead = true;
    final store = TransactionStore(storage: storage);
    await expectLater(store.load(initialTransactions: [old]), throwsStateError);
    expect(storage.writes, 0);
    storage.failRead = false;
    storage.failWrite = true;
    await expectLater(store.load(initialTransactions: [old]), throwsStateError);
    expect(await store.save([]), isFalse);
    storage.failWrite = false;
    expect(await store.load(initialTransactions: [old]), [old]);
    expect(await store.save([]), isTrue);
    expect(storage.value, '[]');
  });

  test(
    'Failed or thrown save preserves stored data and requires reload',
    () async {
      for (final throws in [false, true]) {
        final storage = MemoryStorage(encode([old]));
        final store = TransactionStore(storage: storage);
        await store.load(initialTransactions: []);
        storage.failWrite = !throws;
        storage.throwWrite = throws;
        expect(await store.save([]), isFalse);
        expect(storage.value, encode([old]));
        storage.failWrite = false;
        storage.throwWrite = false;
        expect(await store.save([]), isFalse);
        expect(
          (await store.load(initialTransactions: [])).single.title,
          old.title,
        );
        expect(await store.save([]), isTrue);
      }
    },
  );

  test('Changed storage cannot be overwritten by a stale screen', () async {
    final storage = MemoryStorage(encode([old]));
    final store = TransactionStore(storage: storage);
    await store.load(initialTransactions: []);
    storage.value = '[]';
    expect(await store.save([old]), isFalse);
    expect(storage.value, '[]');
    expect(storage.writes, 0);
  });

  testWidgets(
    'Load failure hides misleading balance and disables add/import until retry',
    (tester) async {
      final storage = MemoryStorage('broken');
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(store: TransactionStore(storage: storage)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry loading'), findsOneWidget);
      expect(find.text('Current Balance'), findsNothing);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('App menu'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MenuItemButton>(
              find.widgetWithText(MenuItemButton, 'Import CSV'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('App menu'));
      await tester.pumpAndSettle();
      expect(storage.writes, 0);
      storage.value = encode([old]);
      await tester.tap(find.text('Retry loading'));
      await tester.pumpAndSettle();
      expect(find.text('Saved transaction'), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
    },
  );

  for (final operation in ['add', 'edit', 'delete']) {
    testWidgets('Failed $operation keeps the previous list and balance', (
      tester,
    ) async {
      final storage = MemoryStorage(encode([old]));
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(store: TransactionStore(storage: storage)),
        ),
      );
      await tester.pumpAndSettle();
      storage.failWrite = true;
      if (operation == 'delete') {
        await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
      } else {
        await tester.tap(
          operation == 'add'
              ? find.byIcon(Icons.add)
              : find.text('Saved transaction'),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'Unsaved transaction',
        );
        await tester.enterText(find.byType(TextField).at(1), '99');
        final button = find.text(
          operation == 'add' ? 'Save Transaction' : 'Update Transaction',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
      }
      await tester.pumpAndSettle();
      expect(find.text('Saved transaction'), findsOneWidget);
      expect(find.text('Unsaved transaction'), findsNothing);
      expect(find.text('€-20.00'), findsOneWidget);
      expect(storage.value, encode([old]));
      expect(find.text('Reload transactions'), findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      storage.failWrite = false;
      await tester.tap(find.text('Reload transactions'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
