import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/services/backup_restore_service.dart';
import 'package:pocket_plan/services/revolut_csv_import.dart';
import 'backup_restore_test.dart' as backup;
import 'revolut_csv_import_test.dart' as csv;

void main() {
  test(
    'Untrusted backup field types, amounts and budget keys never write data',
    () async {
      final before = backup.data('Original');
      final storage = backup.MemoryStorage(before);
      final service = BackupRestoreService(storage: storage);
      final valid =
          jsonDecode(backup.backup(backup.data('Replacement')))
              as Map<String, dynamic>;
      final record =
          (valid['transactions'] as List).single as Map<String, dynamic>;
      final mutations = <Map<String, dynamic>>[
        {'amount': -1},
        {'amount': 0},
        {'amount': '12.5'},
        {'isIncome': 'false'},
        {'title': null},
        {'category': []},
        {'importId': 123},
        {'date': '2026-02-30'},
      ];
      for (final mutation in mutations) {
        await expectLater(
          service.preview(
            jsonEncode({
              ...valid,
              'transactions': [
                {...record, ...mutation},
              ],
            }),
          ),
          throwsA(anything),
        );
        expect(storage.writes, 0);
        expect(storage.values, before);
      }
      for (final budgets in <Map<String, Object>>[
        {'monthly_budget_2026_10': -1},
        {'monthly_budget_2026_10': 1.5},
        {'monthly_budget_2026_10': 9007199254740992},
        {'monthly_budget_0000_01': 10},
        {'unrelated': 'overwrite'},
        {BackupRestoreService.journalKey: 'overwrite'},
      ]) {
        await expectLater(
          service.preview(
            jsonEncode({...valid, 'monthlyBudgetsCents': budgets}),
          ),
          throwsA(anything),
        );
        expect(storage.writes, 0);
        expect(storage.values, before);
      }
    },
  );
  test(
    'Backup byte limit counts UTF-8 bytes and rejects before writes',
    () async {
      final storage = backup.MemoryStorage(backup.data('Original'));
      final before = Map<String, Object?>.of(storage.values);
      final payload = '😀' * (5 * 1024 * 1024 ~/ 4 + 1);
      expect(payload.length, lessThan(5 * 1024 * 1024));
      await expectLater(
        BackupRestoreService(storage: storage).preview(payload),
        throwsA(anything),
      );
      expect(storage.writes, 0);
      expect(storage.values, before);
    },
  );
  test(
    'CSV rejects oversized UTF-8 data and skips non-finite financial values',
    () {
      final parser = RevolutCsvImport();
      expect(
        () => parser.parse('😀' * (RevolutCsvImport.maxBytes ~/ 4 + 1), []),
        throwsFormatException,
      );
      for (final amount in ['Infinity', '-Infinity', 'NaN', '1e999']) {
        final result = parser.parse(
          '${csv.header}\n${csv.body.replaceFirst('-2.00', amount)}',
          [],
        );
        expect(result.rows, isEmpty);
        expect(result.skipped, hasLength(1));
      }
    },
  );
}
