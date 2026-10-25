import 'package:flutter/material.dart';

import '../model/monthly_summary.dart';

/// Each bar shows a category's share of the selected month's total expenses.
class CategorySpendingChart extends StatelessWidget {
  final MonthlySummary summary;

  const CategorySpendingChart({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final categories = summary.expenseByCategory.entries.toList()
      ..sort((a, b) {
        final amountOrder = b.value.compareTo(a.value);
        return amountOrder != 0 ? amountOrder : a.key.compareTo(b.key);
      });
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending by category',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (summary.expense <= 0 || categories.isEmpty)
              const Text('No expenses for this month.')
            else ...[
              const Text('Share of total monthly expenses'),
              const SizedBox(height: 16),
              for (final category in categories)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            category.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '€${category.value.toStringAsFixed(2)} · ${(category.value / summary.expense * 100).toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (category.value / summary.expense).clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                        semanticsLabel: '${category.key} spending',
                        semanticsValue:
                            '${(category.value / summary.expense * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
