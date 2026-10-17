import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String storageKey = 'transactions';

  List<Transaction> transactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  // Kaydedilmiş işlemleri yükler.
  Future<void> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(storageKey);

      List<Transaction> loadedTransactions;

      if (savedData != null) {
        final List<dynamic> decoded = jsonDecode(savedData);

        loadedTransactions = decoded
            .map(
              (item) =>
                  Transaction.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
      } else {
        // Uygulama ilk kez açıldığında örnek işlemler.
        loadedTransactions = [
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

        await prefs.setString(
          storageKey,
          jsonEncode(loadedTransactions.map((t) => t.toJson()).toList()),
        );
      }

      if (!mounted) return;

      setState(() {
        transactions = loadedTransactions;
        isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading transactions: $error');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // İşlemleri kalıcı olarak kaydeder.
  Future<bool> saveTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = transactions
          .map((transaction) => transaction.toJson())
          .toList();

      return await prefs.setString(storageKey, jsonEncode(data));
    } catch (error) {
      debugPrint('Error saving transactions: $error');
      return false;
    }
  }

  Future<void> deleteTransaction(Transaction transaction) async {
    setState(() {
      transactions.remove(transaction);
    });

    final saved = await saveTransactions();

    if (!mounted) return;

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction could not be saved.')),
      );
    }
  }

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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                          transactionKey: ObjectKey(transaction),
                          onDelete: () => deleteTransaction(transaction),

                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddTransactionPage(
                                  transaction: transaction,
                                ),
                              ),
                            );

                            if (!mounted || result == null) return;

                            final index = transactions.indexOf(transaction);

                            if (index == -1) return;

                            setState(() {
                              transactions[index] = Transaction(
                                title: result['title'],
                                category: result['isIncome']
                                    ? 'Income'
                                    : 'Expense',
                                amount: result['amount'],
                                icon: result['isIncome']
                                    ? Icons.account_balance_wallet
                                    : Icons.shopping_cart,
                                isIncome: result['isIncome'],
                              );
                            });

                            final saved = await saveTransactions();

                            if (!mounted) return;

                            if (!saved) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Transaction could not be saved.',
                                  ),
                                ),
                              );
                            }
                          },

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
        onPressed: isLoading
            ? null
            : () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionPage(),
                  ),
                );

                if (!mounted || result == null) return;

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

                final saved = await saveTransactions();

                if (!mounted) return;

                if (!saved) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction could not be saved.'),
                    ),
                  );
                }
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}
