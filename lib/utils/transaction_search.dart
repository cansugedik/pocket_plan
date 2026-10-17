import '../model/transaction.dart';

String _normalize(String value) =>
    value.toLowerCase().replaceAll('ı', 'i').replaceAll('i\u0307', 'i');

/// Matches a literal substring in the title or category, ignoring case.
bool matchesTransactionQuery(Transaction transaction, String query) {
  final term = _normalize(query.trim());
  return term.isEmpty ||
      _normalize(transaction.title).contains(term) ||
      _normalize(transaction.category).contains(term);
}
