import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/model/app_backup.dart';
import 'package:pocket_plan/screens/backup_page.dart';
import 'package:pocket_plan/screens/restore_backup_page.dart';
import 'package:pocket_plan/screens/csv_import_page.dart';
import 'package:pocket_plan/services/backup_service.dart';
import 'package:pocket_plan/services/backup_restore_service.dart';
import 'package:pocket_plan/services/revolut_csv_import.dart';

const csvHeader = 'Type,Completed Date,Description,Amount,Fee,Currency,State';
const csvRow = 'Card Payment,2026-10-15,Tallinja bus,-2.00,0,EUR,COMPLETED';
const merchant = 'A very long merchant name that must wrap on a narrow screen';
const csvSample =
    '$csvHeader\n$csvRow\nCard Payment,2026-10-16,$merchant,-12.50,0,EUR,COMPLETED\nCard Payment,2026-10-17,Pending payment,-1,0,EUR,PENDING';
Map<String, Object?> financial(String title) => {
  'transactions': jsonEncode([
    {
      'title': title,
      'category': 'Other',
      'amount': 12.5,
      'isIncome': false,
      'date': '2026-10-15',
      'importId': 'bank-1',
    },
  ]),
  'monthly_budget_2026_10': 12000,
};

class MemoryDataFile extends XFile {
  final String contents;
  final String filename;
  MemoryDataFile(this.contents, [this.filename = 'test.json'])
    : super(filename);
  @override
  String get name => filename;
  @override
  Future<int> length() async => utf8.encode(contents).length;
  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList(utf8.encode(contents));
}

class MemoryFinancialStorage implements RestoreStorage {
  final Map<String, Object?> values;
  int writes = 0;
  MemoryFinancialStorage(this.values);
  @override
  Future<Map<String, Object?>> readAll() async => {...values};
  @override
  Future<bool> set(String key, Object value) async {
    writes++;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    writes++;
    values.remove(key);
    return true;
  }
}

class MemoryBackupSource implements BackupSource {
  final Map<String, Object?> values;
  MemoryBackupSource(this.values);
  @override
  Future<Map<String, Object?>> read() async => {...values};
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, [
  double delta = 200,
]) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> phone(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final kind in ['CSV', 'Export', 'Restore']) {
    testWidgets('$kind content is centered and bounded on wide screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final Widget page = switch (kind) {
        'CSV' => CsvImportPage(
          existing: const [],
          onImport: (_) async => false,
        ),
        'Export' => const BackupPage(),
        _ => const RestoreBackupPage(),
      };
      await tester.pumpWidget(MaterialApp(home: page));
      final rect = tester.getRect(find.byType(Card).first);
      expect(rect.width, lessThanOrEqualTo(kind == 'CSV' ? 752 : 672));
      expect(rect.center.dx, closeTo(720, 1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Large-text export supports failure, retry and cancel with a fake exporter',
    (tester) async {
      final values = financial('Original');
      final before = {...values};
      var exports = 0;
      await phone(
        tester,
        BackupPage(
          service: BackupService(source: MemoryBackupSource(values)),
          exporter: (backup, origin) async {
            exports++;
            if (exports == 1) throw StateError('Test failure');
            return BackupExportResult.cancelled;
          },
        ),
      );
      await reveal(tester, find.text('Prepare backup'));
      await tester.tap(find.text('Prepare backup'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Export JSON'));
      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();
      await reveal(tester, find.textContaining('Export failed.'));
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Export JSON'), -200);
      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();
      await reveal(tester, find.textContaining('Export cancelled.'));
      expect(exports, 2);
      expect(values, before);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Large-text restore preview and confirmation cancel perform no writes',
    (tester) async {
      final values = financial('Original');
      final before = {...values};
      final storage = MemoryFinancialStorage(values);
      final contents = AppBackup.fromStoredValues(
        financial('Replacement'),
        DateTime.utc(2026, 10, 25),
      ).contents;
      await phone(
        tester,
        RestoreBackupPage(
          service: BackupRestoreService(storage: storage),
          picker: () async => MemoryDataFile(contents),
        ),
      );
      await reveal(tester, find.text('Choose JSON backup'));
      await tester.tap(find.text('Choose JSON backup'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Review restore'));
      expect(find.text('Current: 1 transactions · 1 budgets'), findsOneWidget);
      await tester.tap(find.text('Review restore'));
      await tester.pumpAndSettle();
      expect(find.text('Replace saved data?'), findsOneWidget);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.writes, 0);
      expect(values, before);
    },
  );
  testWidgets(
    'Large-text CSV preview wraps long names and keeps duplicate controls disabled',
    (tester) async {
      final duplicate = RevolutCsvImport()
          .parse('$csvHeader\n$csvRow', [])
          .rows
          .single
          .transaction;
      var imports = 0;
      await phone(
        tester,
        CsvImportPage(
          existing: [duplicate],
          onImport: (_) async {
            imports++;
            return false;
          },
          chooseFile: () async =>
              MemoryDataFile(csvSample, 'revolut-${'long-filename-' * 8}.csv'),
        ),
      );
      await reveal(tester, find.text('Choose CSV file'));
      await tester.tap(find.text('Choose CSV file'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Tallinja bus'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Tallinja bus'),
            )
            .onChanged,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text(merchant));
      await tester.tap(find.text(merchant));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Import 0 selected transactions'), -200);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Import 0 selected transactions',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(imports, 0);
      await reveal(tester, find.text('Skipped rows (1)'));
      await tester.tap(find.text('Skipped rows (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Row 4: Not completed.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final restore in [false, true]) {
    testWidgets(
      '${restore ? 'Restore' : 'CSV'} disables actions and back navigation during file selection',
      (tester) async {
        final picker = Completer<XFile?>();
        var imports = 0;
        final Widget page = restore
            ? RestoreBackupPage(picker: () => picker.future)
            : CsvImportPage(
                existing: const [],
                onImport: (_) async {
                  imports++;
                  return true;
                },
                chooseFile: () => picker.future,
              );
        await tester.pumpWidget(MaterialApp(home: page));
        final label = restore ? 'Choose JSON backup' : 'Choose CSV file';
        await reveal(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pump();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNull,
        );
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
        picker.complete(null);
        await tester.pumpAndSettle();
        expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
        expect(imports, 0);
      },
    );
  }
}
