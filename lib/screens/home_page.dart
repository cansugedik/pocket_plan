import 'package:flutter/material.dart';

import '../widgets/balance_card.dart';
import '../widgets/transaction_item.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pocket Plan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BalanceCard(),
            const SizedBox(height: 24),
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: const [
                  TransactionItem(
                    title: 'Groceries',
                    subtitle: 'Food',
                    amount: '-€45',
                    icon: Icons.shopping_cart,
                  ),
                  TransactionItem(
                    title: 'Salary',
                    subtitle: 'Income',
                    amount: '+€2,100',
                    icon: Icons.account_balance_wallet,
                  ),
                  TransactionItem(
                    title: 'Transport',
                    subtitle: 'Travel',
                    amount: '-€30',
                    icon: Icons.directions_bus,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}