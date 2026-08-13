import 'package:flutter/material.dart';

import 'summary_item.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Balance',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '€1,250',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SummaryItem(
                  title: 'Income',
                  amount: '€2,100',
                  icon: Icons.arrow_downward,
                ),
                SummaryItem(
                  title: 'Expenses',
                  amount: '€850',
                  icon: Icons.arrow_upward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}