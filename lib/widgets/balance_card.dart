import 'package:flutter/material.dart';

import 'summary_item.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    Widget summary(String title, double amount, IconData icon, Color accent) =>
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SummaryItem(
            title: title,
            amount: '€${amount.toStringAsFixed(2)}',
            icon: icon,
            accentColor: accent,
          ),
        );
    final incomeTile = summary(
      'Income',
      income,
      Icons.arrow_downward_rounded,
      dark ? Colors.green.shade300 : Colors.green.shade800,
    );
    final expenseTile = summary(
      'Expenses',
      expense,
      Icons.arrow_upward_rounded,
      dark ? Colors.red.shade300 : Colors.red.shade800,
    );
    return Card.filled(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current Balance',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '€${balance.toStringAsFixed(2)}',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onPrimaryContainer,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                // Stack when space or enlarged text makes two columns hard to read.
                final columns =
                    constraints.maxWidth >= 460 &&
                    MediaQuery.textScalerOf(context).scale(16) <= 22;
                return columns
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: incomeTile),
                          const SizedBox(width: 16),
                          Expanded(child: expenseTile),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          incomeTile,
                          const SizedBox(height: 12),
                          expenseTile,
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}
