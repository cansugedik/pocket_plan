import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/model/app_backup.dart';
import 'package:pocket_plan/screens/restore_backup_page.dart';
import 'package:pocket_plan/services/backup_restore_service.dart';
import 'package:pocket_plan/services/transaction_store.dart';
import 'package:pocket_plan/services/monthly_budget_store.dart';

Map<String, Object?> data(String title, {String month = '10'}) => {
  'transactions': jsonEncode([
    {
      'title': title,
      'category': 'Other',
      'amount': 12.50,
      'icon': 123,
      'isIncome': false,
      'date': '2026-10-21',
      'importId': 'bank-1',
    },
  ]),
  'monthly_budget_2026_$month': 12345,
};
String backup(Map<String, Object?> values) =>
    AppBackup.fromStoredValues(values, DateTime.utc(2026, 10, 21)).contents;

class MemoryStorage implements RestoreStorage {
  final Map<String, Object?> values;
  int writes = 0;
  int? failAt;
  bool failForever = false;
  MemoryStorage(Map<String, Object?> initial) : values = {...initial};
  bool get failed => ++writes == failAt || failForever;
  @override
  Future<Map<String, Object?>> readAll() async => {...values};
  @override
  Future<bool> set(String key, Object value) async {
    if (failed) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (failed) return false;
    values.remove(key);
    return true;
  }
}

class JsonFile extends XFile {
  final String contents;
  JsonFile(this.contents) : super('backup.json');
  @override
  Future<int> length() async => utf8.encode(contents).length;
  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList(utf8.encode(contents));
}

void main() {
  test(
    'Versioned parser rejects invalid/incomplete files without writes',
    () async {
      final valid = jsonDecode(backup(data('New'))) as Map<String, dynamic>;
      final storage = MemoryStorage(data('Old'));
      final service = BackupRestoreService(storage: storage);
      final invalid = [
        '{',
        '[]',
        jsonEncode({...valid, 'version': 2}),
        jsonEncode({...valid, 'version': 1.5}),
        jsonEncode({...valid, 'currency': 'USD'}),
        jsonEncode({
          ...valid,
          'monthlyBudgetsCents': {'transactions': 'bad'},
        }),
        jsonEncode({
          ...valid,
          'transactions': [
            {'title': 'bad'},
          ],
        }),
        jsonEncode({
          ...valid,
          'monthlyBudgetsCents': {'monthly_budget_2026_13': 10},
        }),
        jsonEncode({
          ...valid,
          'transactions': List.filled(
            10001,
            (valid['transactions'] as List).first,
          ),
        }),
        ' ' * (5 * 1024 * 1024 + 1),
      ];
      for (final value in invalid) {
        await expectLater(service.preview(value), throwsA(anything));
      }
      expect(storage.writes, 0);
      expect(storage.values, data('Old'));
    },
  );
  test(
    'Preview is read only; restore replaces budgets and keeps recovery copy',
    () async {
      final before = data('Old');
      final after = data('New', month: '11');
      final storage = MemoryStorage({...before, 'unrelated': 'keep'});
      final service = BackupRestoreService(storage: storage);
      final preview = await service.preview(backup(after));
      expect(storage.writes, 0);
      expect(preview.previousTransactions, 1);
      expect(preview.previousBudgets, 1);
      await service.restore(preview);
      expect(storage.values['transactions'], after['transactions']);
      expect(storage.values['monthly_budget_2026_10'], isNull);
      expect(storage.values['monthly_budget_2026_11'], 12345);
      expect(storage.values['unrelated'], 'keep');
      expect(storage.values[BackupRestoreService.journalKey], isNull);
      expect(
        jsonDecode(storage.values[BackupRestoreService.recoveryKey] as String),
        before,
      );
    },
  );
  test(
    'Empty backup replaces all financial data without touching other keys',
    () async {
      final storage = MemoryStorage({...data('Old'), 'theme': 'keep'});
      final service = BackupRestoreService(storage: storage);
      await service.restore(
        await service.preview(backup({'transactions': '[]'})),
      );
      expect(storage.values['transactions'], '[]');
      expect(
        storage.values.keys.where((k) => k.startsWith('monthly_budget_')),
        isEmpty,
      );
      expect(storage.values['theme'], 'keep');
    },
  );
  test('Changed data since preview aborts before writes', () async {
    final storage = MemoryStorage(data('Old'));
    final service = BackupRestoreService(storage: storage);
    final preview = await service.preview(backup(data('New')));
    storage.values['monthly_budget_2026_10'] = 999;
    await expectLater(service.restore(preview), throwsStateError);
    expect(storage.writes, 0);
    expect(storage.values['monthly_budget_2026_10'], 999);
  });
  test(
    'Failure at every restore write preserves or recovers original data',
    () async {
      // Recovery copy, journal, old budget removal, transaction, new budget, commit.
      for (var failure = 1; failure <= 6; failure++) {
        final before = data('Old');
        final storage = MemoryStorage(before)..failAt = failure;
        final service = BackupRestoreService(storage: storage);
        final preview = await service.preview(backup(data('New', month: '11')));
        await expectLater(service.restore(preview), throwsStateError);
        await service.recoverPending();
        expect(
          storage.values['transactions'],
          before['transactions'],
          reason: 'failure $failure',
        );
        expect(storage.values['monthly_budget_2026_10'], 12345);
        expect(storage.values['monthly_budget_2026_11'], isNull);
      }
    },
  );
  test(
    'Interrupted restore recovers idempotently; failed recovery keeps journal',
    () async {
      final before = data('Old');
      final storage = MemoryStorage({
        ...data('New', month: '11'),
        BackupRestoreService.journalKey: jsonEncode(before),
        BackupRestoreService.recoveryKey: jsonEncode(before),
      });
      storage.failForever = true;
      await expectLater(
        BackupRestoreService(storage: storage).recoverPending(),
        throwsStateError,
      );
      expect(storage.values[BackupRestoreService.journalKey], isNotNull);
      storage.failForever = false;
      await BackupRestoreService(storage: storage).recoverPending();
      await BackupRestoreService(storage: storage).recoverPending();
      expect(storage.values['transactions'], before['transactions']);
      expect(storage.values['monthly_budget_2026_11'], isNull);
    },
  );
  test('Corrupt recovery journal fails closed without writing', () async {
    final storage = MemoryStorage({
      ...data('Old'),
      BackupRestoreService.journalKey: '{',
    });
    await expectLater(
      BackupRestoreService(storage: storage).recoverPending(),
      throwsA(anything),
    );
    expect(storage.writes, 0);
  });
  test(
    'Production reads recover pending journal before transactions and budgets',
    () async {
      final before = data('Old');
      SharedPreferences.setMockInitialValues({
        ...data('Partial', month: '11').map((k, v) => MapEntry(k, v!)),
        BackupRestoreService.journalKey: jsonEncode(before),
      });
      final records = await TransactionStore().load(initialTransactions: []);
      expect(records.single.title, 'Old');
      expect(await MonthlyBudgetStore().load(DateTime(2026, 10)), 12345);
      expect(await MonthlyBudgetStore().load(DateTime(2026, 11)), isNull);
    },
  );
  testWidgets('File preview, explicit cancel, then confirmed restore', (
    tester,
  ) async {
    final storage = MemoryStorage(data('Old'));
    await tester.pumpWidget(
      MaterialApp(
        home: RestoreBackupPage(
          service: BackupRestoreService(storage: storage),
          picker: () async => JsonFile(backup(data('New'))),
        ),
      ),
    );
    await tester.tap(find.text('Choose JSON backup'));
    await tester.pumpAndSettle();
    expect(find.text('Current: 1 transactions · 1 budgets'), findsOneWidget);
    expect(storage.writes, 0);
    await tester.tap(find.text('Review restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.writes, 0);
    await tester.tap(find.text('Review restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace and restore'));
    await tester.pumpAndSettle();
    expect(storage.values['transactions'], data('New')['transactions']);
  });
  testWidgets(
    'Invalid selection clears an earlier preview; picker cancel never writes',
    (tester) async {
      final storage = MemoryStorage(data('Old'));
      var picks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RestoreBackupPage(
            service: BackupRestoreService(storage: storage),
            picker: () async {
              picks++;
              if (picks == 1) return JsonFile(backup(data('New')));
              if (picks == 2) return JsonFile('{');
              return null;
            },
          ),
        ),
      );
      await tester.tap(find.text('Choose JSON backup'));
      await tester.pumpAndSettle();
      expect(find.text('Review restore'), findsOneWidget);
      await tester.tap(find.text('Choose JSON backup'));
      await tester.pumpAndSettle();
      expect(find.text('Review restore'), findsNothing);
      expect(
        find.textContaining('Backup could not be opened.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose JSON backup'));
      await tester.pumpAndSettle();
      expect(storage.writes, 0);
    },
  );
}
