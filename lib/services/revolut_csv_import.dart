import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';

import '../model/transaction.dart';

class CsvImportRow {
  final int line;
  final Transaction transaction;
  final bool duplicate;
  final bool possibleDuplicate;
  const CsvImportRow(
    this.line,
    this.transaction,
    this.duplicate,
    this.possibleDuplicate,
  );
}

class CsvImportPreview {
  final List<CsvImportRow> rows;
  final List<String> skipped;
  const CsvImportPreview(this.rows, this.skipped);
}

class RevolutCsvImport {
  static const maxBytes = 2 * 1024 * 1024;

  CsvImportPreview parse(String source, List<Transaction> existing) {
    if (utf8.encode(source).length > maxBytes) {
      throw const FormatException('Choose a CSV smaller than 2 MB.');
    }
    final rows = csv.decode(source.replaceFirst(RegExp(r'^\uFEFF'), ''));
    if (rows.isEmpty) throw const FormatException('The CSV is empty.');
    if (rows.length > 5001) {
      throw const FormatException(
        'Use a statement with at most 5000 transactions.',
      );
    }
    final headers = rows.first
        .map((v) => v.toString().trim().toLowerCase())
        .toList();
    const required = [
      'type',
      'completed date',
      'description',
      'amount',
      'fee',
      'currency',
      'state',
    ];
    if (headers.toSet().length != headers.length ||
        !required.every(headers.contains)) {
      throw const FormatException(
        'Unsupported columns. Use an English Revolut account CSV with Type, Completed Date, Description, Amount, Fee, Currency and State.',
      );
    }
    final seen = existing.map((t) => t.importId).whereType<String>().toSet();
    final occurrences = <String, int>{};
    final result = <CsvImportRow>[];
    final skipped = <String>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((v) => v.toString().trim().isEmpty)) continue;
      String field(String key) => row[headers.indexOf(key)].toString().trim();
      try {
        if (row.length != headers.length) {
          throw const FormatException('Column count does not match.');
        }
        if (field('state').toUpperCase() != 'COMPLETED') {
          throw const FormatException('Not completed.');
        }
        final type = field('type').toLowerCase();
        if (!['card payment', 'card refund'].contains(type)) {
          throw const FormatException(
            'Not a card payment/refund (transfers are excluded).',
          );
        }
        if (field('currency').toUpperCase() != 'EUR') {
          throw const FormatException('Only EUR is supported.');
        }
        final cents = _signedCents(field('amount'));
        final fee = _signedCents(field('fee'));
        if (cents == null || cents == 0 || fee == null) {
          throw const FormatException('Invalid amount or fee.');
        }
        if (fee != 0) {
          throw const FormatException('Non-zero fee needs manual review.');
        }
        final rawDate = field('completed date');
        final match = RegExp(
          r'^(\d{4})-(\d{2})-(\d{2})(?:[ T].*)?$',
        ).firstMatch(rawDate);
        if (match == null) {
          throw const FormatException('Date must use YYYY-MM-DD.');
        }
        final year = int.parse(match[1]!);
        final month = int.parse(match[2]!);
        final day = int.parse(match[3]!);
        final date = DateTime(year, month, day);
        if (date.year != year || date.month != month || date.day != day) {
          throw const FormatException('Invalid calendar date.');
        }
        final title = field('description');
        if (title.isEmpty) throw const FormatException('Missing description.');
        final signature = jsonEncode([
          'revolut-eur-v1',
          type,
          rawDate,
          title,
          cents,
          headers.contains('started date') ? field('started date') : '',
          headers.contains('product') ? field('product') : '',
        ]);
        final occurrence = occurrences.update(
          signature,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
        final id = '$signature#$occurrence';
        final income = cents > 0;
        final transaction = Transaction(
          title: title,
          category: income ? 'Other' : suggestCategory(title),
          amount: cents.abs() / 100,
          icon: income ? Icons.account_balance_wallet : Icons.shopping_cart,
          isIncome: income,
          date: date,
          importId: id,
        );
        final possible = existing.any(
          (t) =>
              t.importId == null &&
              t.title.toLowerCase() == title.toLowerCase() &&
              t.isIncome == income &&
              (t.amount * 100).round() == cents.abs() &&
              t.date?.year == year &&
              t.date?.month == month &&
              t.date?.day == day,
        );
        result.add(
          CsvImportRow(i + 1, transaction, seen.contains(id), possible),
        );
      } on FormatException catch (e) {
        skipped.add('Row ${i + 1}: ${e.message}');
      }
    }
    return CsvImportPreview(
      List.unmodifiable(result),
      List.unmodifiable(skipped),
    );
  }

  int? _signedCents(String value) {
    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value)) return null;
    final negative = value.startsWith('-');
    final parts = value.replaceFirst('-', '').split('.');
    final units = int.tryParse(parts[0]);
    if (units == null || units > 90071992547409) return null;
    final total =
        units * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    if (total > 9007199254740991) return null;
    return negative ? -total : total;
  }

  static String suggestCategory(String title) {
    final value = title.toLowerCase();
    if (RegExp(r'\b(tallinja|bus|uber|transport)\b').hasMatch(value)) {
      return 'Transport';
    }
    if (RegExp(r'\b(supermarket|grocery|groceries|lidl)\b').hasMatch(value)) {
      return 'Food';
    }
    if (RegExp(r'\b(zara|amazon|shopping)\b').hasMatch(value)) {
      return 'Shopping';
    }
    return 'Other';
  }
}
