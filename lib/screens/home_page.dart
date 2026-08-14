import 'package:flutter/material.dart';

import '../model/transaction.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_item.dart';
import 'add_transaction_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Transaction> transactions = [
    const Transaction(
      title: 'Groceries',
      category: 'Food',
      amount: 45,
      icon: Icons.shopping_cart,
      isIncome: false,
    ),
    const Transaction(
      title: 'Salary',
      category: 'Income',
      amount: 2100,
      icon: Icons.account_balance_wallet,
      isIncome: true,
    ),
    const Transaction(
      title: 'Transport',
      category: 'Travel',
      amount: 30,
      icon: Icons.directions_bus,
      isIncome: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final totalIncome = transactions
        .where((transaction) => transaction.isIncome)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final totalExpense = transactions
        .where((transaction) => !transaction.isIncome)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final balance = totalIncome - totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pocket Plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalanceCard(
              balance: balance,
              income: totalIncome,
              expense: totalExpense,
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];

                  return TransactionItem(
                    title: transaction.title,
                    subtitle: transaction.category,
                    amount: transaction.isIncome
                        ? '+€${transaction.amount.toStringAsFixed(0)}'
                        : '-€${transaction.amount.toStringAsFixed(0)}',
                    icon: transaction.icon,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionPage()),
          );

          if (result == null) {
            return;
          }

          setState(() {
            transactions.insert(
              0,
              Transaction(
                title: result['title'],
                category: result['isIncome'] ? 'Income' : 'Expense',
                amount: result['amount'],
                icon: result['isIncome']
                    ? Icons.account_balance_wallet
                    : Icons.shopping_cart,
                isIncome: result['isIncome'],
              ),
            );
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
