import '../model/transaction.dart';

/// Returns a sorted copy. Undated records stay last in either direction;
/// equal dates keep their existing order, including legacy undated records.
List<Transaction> sortTransactionsByDate(
  List<Transaction> transactions, {
  bool oldestFirst = false,
}) {
  final indexed = transactions.indexed.toList();
  indexed.sort((a, b) {
    final first = a.$2.date;
    final second = b.$2.date;
    if (first == null && second != null) return 1;
    if (first != null && second == null) return -1;
    if (first != null && second != null) {
      final comparison = DateTime(
        first.year,
        first.month,
        first.day,
      ).compareTo(DateTime(second.year, second.month, second.day));
      if (comparison != 0) return oldestFirst ? comparison : -comparison;
    }
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((entry) => entry.$2).toList();
}
