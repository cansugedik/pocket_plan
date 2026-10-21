import 'package:flutter/material.dart';
import '../services/transaction_store.dart';

import '../model/transaction.dart';
import '../utils/transaction_sort.dart';
import '../utils/transaction_search.dart';
import '../utils/transaction_date_filter.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_item.dart';
import 'add_transaction_page.dart';
import 'monthly_summary_page.dart';
import 'csv_import_page.dart';

class HomePage extends StatefulWidget {
  final TransactionStore? store;
  const HomePage({super.key, this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TransactionStore store;
  bool isSaving = false;
  bool writesBlocked = false;

  bool get canWrite => !isLoading && !loadFailed && !writesBlocked && !isSaving;

  List<Transaction> transactions = [];
  bool isLoading = true;
  bool loadFailed = false;
  final searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool oldestFirst = false;
  String typeFilter = 'all';
  String? categoryFilter;
  String? monthFilter;
  DateTime? searchDate;

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
    store = widget.store ?? TransactionStore();
    loadTransactions();
  }

  // Existing data is never replaced with defaults after a failed load.
  Future<void> loadTransactions() async {
    if (isSaving) return;
    setState(() {
      isLoading = true;
      loadFailed = false;
    });
    try {
      final initial = [
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
      final loaded = await store.load(initialTransactions: initial);
      if (!mounted) return;
      setState(() {
        transactions = loaded;
        isLoading = false;
        writesBlocked = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadFailed = true;
        writesBlocked = true;
      });
    }
  }

  Future<bool> saveTransactions(List<Transaction> candidates) async {
    if (!canWrite) return false;
    setState(() => isSaving = true);
    final saved = await store.save(candidates);
    if (!mounted) return saved;
    setState(() {
      isSaving = false;
      if (saved) {
        transactions = candidates;
      } else {
        writesBlocked = true;
      }
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Changes could not be saved. Previous transactions are still shown. Reload before trying again.',
          ),
        ),
      );
    }
    return saved;
  }

  Future<bool> deleteTransaction(Transaction transaction) async {
    if (!canWrite) return false;
    final candidates = List<Transaction>.of(transactions)..remove(transaction);
    // The row is removed after persistence; Dismissible must not animate an already removed row.
    await saveTransactions(candidates);
    return false;
  }

  Future<void> openCsvImport() async {
    if (!canWrite) return;
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => CsvImportPage(
          existing: List.unmodifiable(transactions),
          onImport: (incoming) async {
            if (!canWrite) return false;
            final ids = transactions
                .map((t) => t.importId)
                .whereType<String>()
                .toSet();
            if (incoming.any(
              (t) => t.importId == null || !ids.add(t.importId!),
            )) {
              return false;
            }
            return saveTransactions([...incoming, ...transactions]);
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$result transactions imported.')));
  }

  @override
  Widget build(BuildContext context) {
    final matchingTransactions = transactions.where((t) {
      if (!matchesTransactionQuery(t, searchQuery)) return false;
      if (typeFilter == 'income' && !t.isIncome) return false;
      if (typeFilter == 'expense' && t.isIncome) return false;
      if (categoryFilter != null && t.category != categoryFilter) return false;
      if (!matchesTransactionDate(t.date, searchDate)) return false;
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
        actions: [
          IconButton(
            tooltip: 'Import CSV',
            onPressed: canWrite ? openCsvImport : null,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Monthly summary',
            onPressed: isLoading
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MonthlySummaryPage(
                        transactions: List.unmodifiable(transactions),
                        initialMonth:
                            monthFilter != null && monthFilter != 'undated'
                            ? DateTime.parse('$monthFilter-01')
                            : null,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.calendar_month),
          ),
        ],
        title: const Text(
          'Pocket Plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : loadFailed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Transactions could not be loaded. Your saved data has not been replaced.',
                    ),
                    TextButton(
                      onPressed: loadTransactions,
                      child: const Text('Retry loading'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (writesBlocked)
                          MaterialBanner(
                            content: const Text(
                              'Saving is paused to protect your data. Reload transactions to continue.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: loadTransactions,
                                child: const Text('Reload transactions'),
                              ),
                            ],
                          ),
                        if (isSaving) const LinearProgressIndicator(),
                        if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                          BalanceCard(
                            balance: balance,
                            income: totalIncome,
                            expense: totalExpense,
                          ),
                          const SizedBox(height: 24),
                        ],
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
                              label: Text(
                                hasFilters ? 'Filters on' : 'Filters',
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const ValueKey('transaction-search'),
                                controller: searchController,
                                onChanged: (value) =>
                                    setState(() => searchQuery = value),
                                decoration: InputDecoration(
                                  labelText: 'Search transactions',
                                  hintText: 'Title or category',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: searchQuery.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          icon: const Icon(Icons.clear),
                                          onPressed: () => setState(() {
                                            searchController.clear();
                                            searchQuery = '';
                                          }),
                                        ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Search by date',
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: searchDate ?? DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2100, 12, 31),
                                );
                                if (!mounted || picked == null) return;
                                setState(() => searchDate = picked);
                              },
                              icon: const Icon(Icons.calendar_today),
                            ),
                          ],
                        ),
                        if (searchDate != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InputChip(
                              label: Text(
                                'Date: ${MaterialLocalizations.of(context).formatShortDate(searchDate!)}',
                              ),
                              onDeleted: () =>
                                  setState(() => searchDate = null),
                              deleteButtonTooltipMessage: 'Clear search date',
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${oldestFirst ? 'Oldest first' : 'Newest first'} · Undated last',
                        ),
                        if (hasFilters) ...[
                          const Text(
                            'Search and filters affect the list. Balance shows all transactions.',
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
                      ],
                    ),
                  ),
                ],
                body: visibleTransactions.isEmpty
                    ? Center(
                        child: Text(
                          searchQuery.trim().isNotEmpty || searchDate != null
                              ? 'No transactions match your search and filters.'
                              : hasFilters
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
                            enabled: canWrite,

                            onTap: () async {
                              if (!canWrite) return;
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

                              final candidates = List<Transaction>.of(
                                transactions,
                              );
                              candidates[index] = Transaction(
                                importId: transaction.importId,
                                title: result['title'],
                                category: result['category'],
                                date: result['date'],
                                amount: result['amount'],
                                icon: result['isIncome']
                                    ? Icons.account_balance_wallet
                                    : Icons.shopping_cart,
                                isIncome: result['isIncome'],
                              );
                              await saveTransactions(candidates);
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: !canWrite
            ? null
            : () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionPage(),
                  ),
                );

                if (!mounted || result == null) return;

                await saveTransactions([
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
                  ...transactions,
                ]);
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}
