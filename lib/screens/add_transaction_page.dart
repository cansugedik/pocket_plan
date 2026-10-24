import 'package:flutter/material.dart';

import '../model/transaction.dart';

class AddTransactionPage extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionPage({super.key, this.transaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  static const incomeCategories = ['Salary', 'Freelance', 'Gift', 'Other'];
  static const expenseCategories = [
    'Food',
    'Shopping',
    'Transport',
    'Bills',
    'Health',
    'Entertainment',
    'Other',
  ];

  bool isIncome = true;
  String selectedCategory = 'Other';
  DateTime? selectedDate;

  List<String> get categories {
    final options = isIncome ? incomeCategories : expenseCategories;
    final original = widget.transaction;
    if (original != null &&
        original.isIncome == isIncome &&
        !options.contains(original.category)) {
      return [...options, original.category];
    }
    return options;
  }

  void changeType(bool value) {
    setState(() {
      isIncome = value;
      if (!categories.contains(selectedCategory)) {
        selectedCategory = 'Other';
      }
    });
  }

  final titleFocus = FocusNode();
  final amountFocus = FocusNode();
  String? titleError;
  String? amountError;

  final titleController = TextEditingController();
  final amountController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    final now = DateTime.now();
    selectedDate = transaction == null
        ? DateTime(now.year, now.month, now.day)
        : transaction.date;

    if (transaction != null) {
      titleController.text = transaction.title;
      amountController.text = transaction.amount.toString();
      isIncome = transaction.isIncome;
      selectedCategory = transaction.category;
    }
  }

  @override
  void dispose() {
    titleFocus.dispose();
    amountFocus.dispose();
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  double? parseAmount() =>
      double.tryParse(amountController.text.trim().replaceAll(',', '.'));

  String? validateAmount() {
    final amount = parseAmount();
    return amount == null || !amount.isFinite || amount <= 0
        ? 'Enter an amount greater than zero.'
        : null;
  }

  void submit() {
    final title = titleController.text.trim();
    setState(() {
      titleError = title.isEmpty ? 'Enter a title.' : null;
      amountError = validateAmount();
    });
    if (titleError != null || amountError != null) {
      (titleError != null ? titleFocus : amountFocus).requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.pop(context, {
      'title': title,
      'amount': parseAmount()!,
      'isIncome': isIncome,
      'category': selectedCategory,
      'date': selectedDate,
    });
  }

  Future<void> chooseDate() async {
    final initial = selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 1900 ? initial.year : 1900),
      lastDate: DateTime(initial.year > 2100 ? initial.year : 2100, 12, 31),
    );
    if (!mounted || picked == null) return;
    setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    InputDecoration decoration(String label, {String? error, String? prefix}) =>
        InputDecoration(
          labelText: label,
          prefixText: prefix,
          errorText: error,
          errorMaxLines: 3,
          filled: true,
          fillColor: colors.surfaceContainerLow,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );
    Widget typeChoice(bool income) => SizedBox(
      width: double.infinity,
      child: ChoiceChip(
        label: Text(income ? 'Income' : 'Expense'),
        avatar: Icon(
          isIncome == income
              ? Icons.check
              : income
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
        ),
        selected: isIncome == income,
        onSelected: (_) => changeType(income),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text('Transaction type', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 320 ||
                        MediaQuery.textScalerOf(context).scale(16) > 22;
                    return stacked
                        ? Column(
                            children: [
                              typeChoice(true),
                              const SizedBox(height: 8),
                              typeChoice(false),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: typeChoice(true)),
                              const SizedBox(width: 12),
                              Expanded(child: typeChoice(false)),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 24),
                TextField(
                  key: const ValueKey('transaction-title'),
                  controller: titleController,
                  focusNode: titleFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => amountFocus.requestFocus(),
                  onChanged: (value) {
                    if (titleError != null) {
                      setState(
                        () => titleError = value.trim().isEmpty
                            ? 'Enter a title.'
                            : null,
                      );
                    }
                  },
                  decoration: decoration('Title', error: titleError),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('transaction-amount'),
                  controller: amountController,
                  focusNode: amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (_) {
                    if (amountError != null) {
                      setState(() => amountError = validateAmount());
                    }
                  },
                  decoration: decoration(
                    'Amount (EUR)',
                    error: amountError,
                    prefix: '€ ',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(isIncome),
                  initialValue: selectedCategory,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: decoration('Category'),
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedCategory = value);
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('transaction-date'),
                  icon: const Icon(Icons.calendar_today),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: Text(
                    selectedDate == null
                        ? 'Date: Not specified'
                        : 'Date: ${MaterialLocalizations.of(context).formatMediumDate(selectedDate!)}',
                  ),
                  onPressed: chooseDate,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onPressed: submit,
                  icon: const Icon(Icons.check),
                  label: Text(
                    isEditing ? 'Update Transaction' : 'Save Transaction',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
