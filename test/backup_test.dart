import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/model/app_backup.dart';
import 'package:pocket_plan/screens/backup_page.dart';
import 'package:pocket_plan/services/backup_service.dart';

Map<String, Object?> sample() => {
  'transactions': jsonEncode([
    {
      'title': 'Bus',
      'category': 'Transport',
      'amount': 2.5,
      'icon': 123,
      'isIncome': false,
      'date': '2026-10-21',
      'importId': 'source-1',
      'futureField': 'preserved',
    },
    {'title': 'Gift', 'category': 'Gift', 'amount': 10, 'isIncome': true},
  ]),
  'monthly_budget_2026_10': 50000,
};

class FakeSource implements BackupSource {
  final Map<String, Object?> values;
  int reads = 0;
  bool changing = false;
  bool fail = false;
  FakeSource(this.values);
  @override
  Future<Map<String, Object?>> read() async {
    if (fail) throw StateError('Unavailable');
    reads++;
    return {
      ...values,
      if (changing && reads > 1) 'monthly_budget_2026_11': 100,
    };
  }
}

void main() {
  test('Export preserves all fields, undated records, cents and metadata', () {
    final source = sample();
    final backup = AppBackup.fromStoredValues(
      source,
      DateTime.utc(2026, 10, 21),
    );
    final json = jsonDecode(backup.contents) as Map;
    expect(json['version'], 1);
    expect(json['transactions'], jsonDecode(source['transactions'] as String));
    expect(json['monthlyBudgetsCents'], {'monthly_budget_2026_10': 50000});
    expect(backup.transactionCount, 2);
    expect(backup.budgetCount, 1);
    expect(backup.fileName, endsWith('.json'));
    expect(source, sample());
  });
  test('Empty stored list is supported; missing/corrupt data is rejected', () {
    expect(
      AppBackup.fromStoredValues({
        'transactions': '[]',
      }, DateTime.now()).transactionCount,
      0,
    );
    for (final values in [
      <String, Object?>{},
      {'transactions': '{'},
      {...sample(), 'monthly_budget_2026_13': 10},
      {...sample(), 'monthly_budget_2026_10': -1},
      {
        'transactions':
            '[{"title":"Bad","category":"Other","amount":2,"isIncome":false,"date":"2026-02-30"}]',
      },
    ]) {
      expect(
        () => AppBackup.fromStoredValues(values, DateTime.now()),
        throwsA(anything),
      );
    }
  });
  test('Changing or unavailable storage aborts export', () async {
    final source = FakeSource(sample())..changing = true;
    await expectLater(BackupService(source: source).create(), throwsStateError);
    source.fail = true;
    await expectLater(BackupService(source: source).create(), throwsStateError);
  });
  test(
    'Preferences export does not write or include unrelated settings',
    () async {
      SharedPreferences.setMockInitialValues({
        ...sample().map((key, value) => MapEntry(key, value!)),
        'private_setting': 'omit',
      });
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final backup = await BackupService().create();
      expect(backup.contents, isNot(contains('private_setting')));
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
    },
  );
  testWidgets(
    'Prepare, cancel, error and retry export without modifying source',
    (tester) async {
      final source = FakeSource(sample());
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BackupPage(
            service: BackupService(source: source),
            exporter: (backup, origin) async {
              calls++;
              expect(backup.transactionCount, 2);
              expect(origin.width, greaterThan(0));
              if (calls == 1) return BackupExportResult.cancelled;
              if (calls == 2) throw StateError('Save failed');
              return BackupExportResult.requested;
            },
          ),
        ),
      );
      expect(find.text('Export JSON'), findsNothing);
      await tester.tap(find.text('Prepare backup'));
      await tester.pumpAndSettle();
      expect(find.text('2 transactions · 1 monthly budgets'), findsOneWidget);
      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Export cancelled.'), findsOneWidget);
      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Export failed.'), findsOneWidget);
      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Export requested.'), findsOneWidget);
      source.fail = true;
      await tester.tap(find.text('Prepare fresh backup'));
      await tester.pumpAndSettle();
      expect(find.text('Export JSON'), findsNothing);
      expect(
        find.textContaining('Backup could not be prepared.'),
        findsOneWidget,
      );
      expect(source.values, sample());
    },
  );
}
