import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/model/transaction.dart';
import 'package:pocket_plan/utils/transaction_sort.dart';

Transaction record(String title, [DateTime? date]) => Transaction(
  title: title,
  category: 'Other',
  amount: 10,
  icon: Icons.shopping_cart,
  isIncome: false,
  date: date,
);

void main() {
  test('Both date orders are stable, undated last, without mutating input', () {
    final records = [
      record('legacy A'),
      record('older', DateTime(2025, 12, 31)),
      record('newer A', DateTime(2026, 1, 1)),
      record('legacy B'),
      record('newer B', DateTime(2026, 1, 1)),
    ];
    final before = List<Transaction>.of(records);
    expect(sortTransactionsByDate(records).map((t) => t.title).toList(), [
      'newer A',
      'newer B',
      'older',
      'legacy A',
      'legacy B',
    ]);
    expect(
      sortTransactionsByDate(
        records,
        oldestFirst: true,
      ).map((t) => t.title).toList(),
      ['older', 'newer A', 'newer B', 'legacy A', 'legacy B'],
    );
    expect(records, before);
  });

  test('Empty, single and all-undated lists are supported', () {
    expect(sortTransactionsByDate([]), isEmpty);
    final one = [record('single', DateTime(2026, 1, 1))];
    expect(sortTransactionsByDate(one), one);
    final undated = [record('first'), record('second')];
    expect(sortTransactionsByDate(undated), undated);
    expect(sortTransactionsByDate(undated, oldestFirst: true), undated);
  });
}
