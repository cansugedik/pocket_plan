import 'transaction.dart';

class MonthlySummary {
  final double income;
  final double expense;
  final int transactionCount;

  const MonthlySummary({
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  double get balance => income - expense;

  factory MonthlySummary.fromTransactions(
    Iterable<Transaction> transactions,
    DateTime month,
  ) {
    var income = 0.0;
    var expense = 0.0;
    var count = 0;
    for (final transaction in transactions) {
      final date = transaction.date;
      if (date == null ||
          date.year != month.year ||
          date.month != month.month) {
        continue;
      }
      count++;
      if (transaction.isIncome) {
        income += transaction.amount;
      } else {
        expense += transaction.amount;
      }
    }
    return MonthlySummary(
      income: income,
      expense: expense,
      transactionCount: count,
    );
  }
}
