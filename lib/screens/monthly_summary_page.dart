import 'package:flutter/material.dart';

import '../model/monthly_summary.dart';
import '../model/transaction.dart';
import '../widgets/balance_card.dart';
import '../widgets/category_spending_chart.dart';
import '../widgets/monthly_budget_card.dart';

class MonthlySummaryPage extends StatefulWidget {
  final List<Transaction> transactions;
  final DateTime? initialMonth;

  const MonthlySummaryPage({
    super.key,
    required this.transactions,
    this.initialMonth,
  });

  @override
  State<MonthlySummaryPage> createState() => _MonthlySummaryPageState();
}

class _MonthlySummaryPageState extends State<MonthlySummaryPage> {
  late DateTime month;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    month = DateTime(initial.year, initial.month);
  }

  void changeMonth(int offset) {
    setState(() => month = DateTime(month.year, month.month + offset));
  }

  @override
  Widget build(BuildContext context) {
    final summary = MonthlySummary.fromTransactions(widget.transactions, month);
    final undatedCount = widget.transactions
        .where((t) => t.date == null)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly summary')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card.filled(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => changeMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMonthYear(month),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          onPressed: () => changeMonth(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() => month = DateTime(now.year, now.month));
                  },
                  child: const Text('This month'),
                ),
                BalanceCard(
                  title: 'Monthly balance',
                  balanceKey: const ValueKey('monthly-balance'),
                  balance: summary.balance,
                  income: summary.income,
                  expense: summary.expense,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.transactionCount} ${summary.transactionCount == 1 ? 'transaction' : 'transactions'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (summary.transactionCount == 0) ...[
                        const SizedBox(height: 8),
                        const Text('No dated transactions for this month.'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                MonthlyBudgetCard(
                  key: ValueKey('${month.year}-${month.month}'),
                  month: month,
                  expenses: summary.expense,
                ),
                const SizedBox(height: 16),
                CategorySpendingChart(summary: summary),
                const SizedBox(height: 16),
                const Text(
                  'This summary includes all categories and transaction types for the selected month.',
                ),
                if (undatedCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$undatedCount undated transactions are excluded from monthly totals. They remain in your overall balance.',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
