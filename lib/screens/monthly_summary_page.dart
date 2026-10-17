import 'package:flutter/material.dart';

import '../model/monthly_summary.dart';
import '../model/transaction.dart';
import '../widgets/summary_item.dart';
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  MaterialLocalizations.of(context).formatMonthYear(month),
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
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() => month = DateTime(now.year, now.month));
            },
            child: const Text('This month'),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly balance'),
                  const SizedBox(height: 8),
                  Text(
                    '€${summary.balance.toStringAsFixed(2)}',
                    key: const ValueKey('monthly-balance'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 32,
                    runSpacing: 16,
                    children: [
                      SummaryItem(
                        title: 'Income',
                        amount: '€${summary.income.toStringAsFixed(2)}',
                        icon: Icons.arrow_downward,
                      ),
                      SummaryItem(
                        title: 'Expenses',
                        amount: '€${summary.expense.toStringAsFixed(2)}',
                        icon: Icons.arrow_upward,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${summary.transactionCount} ${summary.transactionCount == 1 ? 'transaction' : 'transactions'}',
                  ),
                  if (summary.transactionCount == 0) ...[
                    const SizedBox(height: 8),
                    const Text('No dated transactions for this month.'),
                  ],
                ],
              ),
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
    );
  }
}
