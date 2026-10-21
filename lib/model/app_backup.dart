import 'dart:convert';

import 'transaction.dart';

/// Versioned export envelope. Stored transaction fields are preserved verbatim.
class AppBackup {
  final String contents;
  final DateTime createdAt;
  final int transactionCount;
  final int budgetCount;

  const AppBackup._(
    this.contents,
    this.createdAt,
    this.transactionCount,
    this.budgetCount,
  );

  factory AppBackup.fromStoredValues(
    Map<String, Object?> values,
    DateTime now,
  ) {
    final raw = values['transactions'];
    if (raw is! String) throw const FormatException('Transactions unavailable');
    final records = jsonDecode(raw) as List;
    for (final record in records) {
      final json = Map<String, dynamic>.from(record as Map);
      final transaction = Transaction.fromJson(json);
      if (!transaction.amount.isFinite ||
          transaction.amount <= 0 ||
          (json['date'] != null &&
              (transaction.date == null ||
                  transaction.date!.toIso8601String().split('T').first !=
                      json['date']))) {
        throw const FormatException('Invalid transaction');
      }
    }
    final budgets = <String, int>{};
    final keys =
        values.keys.where((key) => key.startsWith('monthly_budget_')).toList()
          ..sort();
    for (final key in keys) {
      final match = RegExp(
        r'^monthly_budget_([0-9]{4})_(0[1-9]|1[0-2])$',
      ).firstMatch(key);
      final cents = values[key];
      if (match == null ||
          int.parse(match[1]!) == 0 ||
          cents is! int ||
          cents <= 0 ||
          cents > 9007199254740991) {
        throw const FormatException('Invalid budget');
      }
      budgets[key] = cents;
    }
    final created = now.toUtc();
    return AppBackup._(
      const JsonEncoder.withIndent('  ').convert({
        'format': 'pocket-plan-backup',
        'version': 1,
        'createdAt': created.toIso8601String(),
        'currency': 'EUR',
        'transactions': records,
        'monthlyBudgetsCents': budgets,
      }),
      created,
      records.length,
      budgets.length,
    );
  }

  /// Accept only our complete version-1 envelope; never partially import a file.
  factory AppBackup.parse(String contents) {
    if (utf8.encode(contents).length > 5 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 5 MB');
    }
    final json = jsonDecode(contents);
    if (json is! Map<String, dynamic> ||
        json['format'] != 'pocket-plan-backup' ||
        json['version'] is! int ||
        json['version'] != 1 ||
        json['currency'] != 'EUR' ||
        json['createdAt'] is! String ||
        json['transactions'] is! List ||
        json['monthlyBudgetsCents'] is! Map ||
        (json['transactions'] as List).length > 10000) {
      throw const FormatException('Unsupported backup');
    }
    final created = DateTime.tryParse(json['createdAt'] as String);
    if (created == null) throw const FormatException('Invalid backup date');
    final budgets = Map<String, Object?>.from(
      json['monthlyBudgetsCents'] as Map,
    );
    if (budgets.keys.any((key) => !key.startsWith('monthly_budget_'))) {
      throw const FormatException('Invalid budget key');
    }
    return AppBackup.fromStoredValues({
      'transactions': jsonEncode(json['transactions']),
      ...budgets,
    }, created);
  }

  String get fileName =>
      'pocket-plan-backup-${createdAt.toIso8601String().replaceAll(':', '-')}.json';
}
