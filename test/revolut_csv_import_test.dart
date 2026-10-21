import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/screens/csv_import_page.dart';
import 'package:pocket_plan/services/revolut_csv_import.dart';

const header =
    'Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance';
const body =
    'Card Payment,Current,2026-10-14 09:00:00,2026-10-15 09:00:00,Tallinja bus,-2.00,0.00,EUR,COMPLETED,98.00';
const sample = '$header\n$body';

class MemoryCsvFile extends XFile {
  MemoryCsvFile() : super('sample.csv');
  @override
  String get name => 'sample.csv';
  @override
  Future<int> length() async => utf8.encode(sample).length;
  @override
  Future<Uint8List> readAsBytes() async =>
      Uint8List.fromList(utf8.encode(sample));
}

void main() {
  test('Parses BOM, quoted commas/newlines, CRLF and category suggestions', () {
    final result = RevolutCsvImport().parse(
      '\uFEFF$header\r\n$body\r\n'
      'Card Payment,Current,2026-10-14,2026-10-15,"Shop, with\nnewline",-12.50,0,EUR,COMPLETED,85.50',
      [],
    );
    expect(result.rows.length, 2);
    expect(result.rows.first.transaction.category, 'Transport');
    expect(result.rows.first.transaction.amount, 2);
    expect(result.rows.first.transaction.date, DateTime(2026, 10, 15));
    expect(result.rows.last.transaction.title, 'Shop, with\nnewline');
    expect(result.skipped, isEmpty);
  });

  test(
    'Unsupported rows are explained; invalid dates and currency are never silently imported',
    () {
      final result = RevolutCsvImport().parse(
        '$sample\n'
        '${body.replaceFirst('COMPLETED', 'PENDING')}\n'
        '${body.replaceFirst('EUR', 'USD')}\n'
        '${body.replaceFirst('Card Payment', 'Transfer')}\n'
        '${body.replaceFirst('2026-10-15 09:00:00', '2026-02-30')}\n'
        '${body.replaceFirst('-2.00,0.00', '-2.00,1.00')}\n'
        '${body.replaceFirst('-2.00', 'NaN')}\n'
        'bad,row',
        [],
      );
      expect(result.rows.length, 1);
      expect(result.skipped.length, 7);
      expect(
        () => RevolutCsvImport().parse(
          'date,title,amount\n2026-10-15,test,1',
          [],
        ),
        throwsFormatException,
      );
      expect(() => RevolutCsvImport().parse('', []), throwsFormatException);
    },
  );

  test(
    'Import identities survive JSON and edits, matching manual rows are flagged',
    () {
      final imported = RevolutCsvImport()
          .parse(sample, [])
          .rows
          .single
          .transaction;
      final restored = Transaction.fromJson(imported.toJson());
      expect(
        RevolutCsvImport().parse(sample, [restored]).rows.single.duplicate,
        isTrue,
      );
      final edited = Transaction(
        title: 'Changed',
        category: 'Other',
        amount: 5,
        icon: imported.icon,
        isIncome: false,
        date: imported.date,
        importId: imported.importId,
      );
      expect(
        RevolutCsvImport().parse(sample, [edited]).rows.single.duplicate,
        isTrue,
      );
      final manual = Transaction(
        title: imported.title,
        category: imported.category,
        amount: imported.amount,
        icon: imported.icon,
        isIncome: false,
        date: imported.date,
      );
      expect(
        RevolutCsvImport()
            .parse(sample, [manual])
            .rows
            .single
            .possibleDuplicate,
        isTrue,
      );
      final identical = RevolutCsvImport().parse('$sample\n$body', []);
      expect(
        identical.rows[0].transaction.importId,
        isNot(identical.rows[1].transaction.importId),
      );
      expect(
        RevolutCsvImport()
            .parse(
              '$sample\n$body',
              identical.rows.map((r) => r.transaction).toList(),
            )
            .rows
            .every((r) => r.duplicate),
        isTrue,
      );
    },
  );

  testWidgets(
    'Preview requires explicit confirmation and lets user correct category',
    (tester) async {
      List<Transaction>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: CsvImportPage(
            existing: const [],
            chooseFile: () async => MemoryCsvFile(),
            onImport: (rows) async {
              saved = rows;
              return false;
            },
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Choose CSV file'), 150);
      await tester.tap(find.text('Choose CSV file'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tester.scrollUntilVisible(find.text('Tallinja bus'), 150);
      await tester.pumpAndSettle();
      expect(find.text('Tallinja bus'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Import 1 selected transactions'),
        -150,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import 1 selected transactions'));
      await tester.pumpAndSettle();
      expect(saved!.single.category, 'Shopping');
      expect(
        find.text(
          'Import could not be saved. No records were added. Please try again.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Cancel choosing a file leaves preview empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CsvImportPage(
          existing: const [],
          chooseFile: () async => null,
          onImport: (_) async => throw StateError('Must not save'),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Choose CSV file'), 150);
    await tester.tap(find.text('Choose CSV file'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Already imported records cannot be selected again', (
    tester,
  ) async {
    final imported = RevolutCsvImport()
        .parse(sample, [])
        .rows
        .single
        .transaction;
    await tester.pumpWidget(
      MaterialApp(
        home: CsvImportPage(
          existing: [imported],
          chooseFile: () async => MemoryCsvFile(),
          onImport: (_) async => throw StateError('Must not save'),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Choose CSV file'), 150);
    await tester.tap(find.text('Choose CSV file'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Tallinja bus'), 150);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.text('Import 0 selected transactions'),
      -150,
    );
    expect(find.text('Import 0 selected transactions'), findsOneWidget);
  });
}
