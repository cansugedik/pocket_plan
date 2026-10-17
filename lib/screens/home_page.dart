import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/transaction.dart';
import '../utils/transaction_sort.dart';
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
  bool oldestFirst = false;
  String typeFilter = 'all';
  String? categoryFilter;
  String? monthFilter;

  bool get hasFilters =>
      typeFilter != 'all' || categoryFilter != null || monthFilter != null;

  String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Future<void> showFilters() async {
    var type = typeFilter;
    var category = categoryFilter;
    var month = monthFilter;
    final categories = transactions.map((t) => t.category).toSet();
    if (category != null) categories.add(category);
    final sortedCategories = categories.toList()..sort();
    final months = transactions
        .where((t) => t.date != null)
        .map((t) => monthKey(t.date!))
        .toSet();
    if (month != null && month != 'undated') months.add(month);
    final sortedMonths = months.toList()..sort((a, b) => b.compareTo(a));
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filter transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('type-$type'),
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All types')),
                    DropdownMenuItem(value: 'income', child: Text('Income')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  ],
                  onChanged: (value) => setSheetState(() => type = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('category-$category'),
                  initialValue: category,
                  hint: const Text('All categories'),
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...sortedCategories.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => category = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('month-$month'),
                  initialValue: month,
                  hint: const Text('All dates'),
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All dates'),
                    ),
                    const DropdownMenuItem(
                      value: 'undated',
                      child: Text('Date not specified'),
                    ),
                    ...sortedMonths.map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMonthYear(DateTime.parse('$m-01')),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => month = value),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Apply filters'),
                ),
                TextButton(
                  onPressed: () {
                    setSheetState(() {
                      type = 'all';
                      category = null;
                      month = null;
                    });
                  },
                  child: const Text('Reset filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || result != true) return;
    setState(() {
      typeFilter = type;
      categoryFilter = category;
      monthFilter = month;
    });
  }

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
    final matchingTransactions = transactions.where((t) {
      if (typeFilter == 'income' && !t.isIncome) return false;
      if (typeFilter == 'expense' && t.isIncome) return false;
      if (categoryFilter != null && t.category != categoryFilter) return false;
      if (monthFilter == 'undated') return t.date == null;
      if (monthFilter != null) {
        return t.date != null && monthKey(t.date!) == monthFilter;
      }
      return true;
    }).toList();

    final visibleTransactions = sortTransactionsByDate(
      matchingTransactions,
      oldestFirst: oldestFirst,
    );

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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuButton<bool>(
                        tooltip: 'Sort by date',
                        icon: const Icon(Icons.sort),
                        initialValue: oldestFirst,
                        onSelected: (value) =>
                            setState(() => oldestFirst = value),
                        itemBuilder: (context) => [
                          CheckedPopupMenuItem(
                            value: false,
                            checked: !oldestFirst,
                            child: const Text('Newest first'),
                          ),
                          CheckedPopupMenuItem(
                            value: true,
                            checked: oldestFirst,
                            child: const Text('Oldest first'),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: showFilters,
                        icon: const Icon(Icons.filter_list),
                        label: Text(hasFilters ? 'Filters on' : 'Filters'),
                      ),
                    ],
                  ),
                  Text(
                    '${oldestFirst ? 'Oldest first' : 'Newest first'} · Undated last',
                  ),
                  if (hasFilters) ...[
                    const Text(
                      'Filters affect the list. Balance shows all transactions.',
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        typeFilter = 'all';
                        categoryFilter = null;
                        monthFilter = null;
                      }),
                      child: const Text('Clear filters'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: visibleTransactions.isEmpty
                        ? Center(
                            child: Text(
                              hasFilters
                                  ? 'No transactions match your filters.'
                                  : 'No transactions yet.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: visibleTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = visibleTransactions[index];

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

                                  final index = transactions.indexOf(
                                    transaction,
                                  );

                                  if (index == -1) return;

                                  setState(() {
                                    transactions[index] = Transaction(
                                      title: result['title'],
                                      category: result['category'],
                                      date: result['date'],
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
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
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
                                dateLabel: transaction.date == null
                                    ? 'Date not specified'
                                    : MaterialLocalizations.of(
                                        context,
                                      ).formatMediumDate(transaction.date!),
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
                      category: result['category'],
                      date: result['date'],
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
                  ScaffoldMessenger.of(this.context).showSnackBar(
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
