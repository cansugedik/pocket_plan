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

  final titleController = TextEditingController();
  final amountController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;

    if (transaction != null) {
      titleController.text = transaction.title;
      amountController.text = transaction.amount.toString();
      isIncome = transaction.isIncome;
      selectedCategory = transaction.category;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      changeType(true);
                    },
                    child: Text(isIncome ? '✓ Income' : 'Income'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      changeType(false);
                    },
                    child: Text(!isIncome ? '✓ Expense' : 'Expense'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              key: ValueKey(isIncome),
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCategory = value);
                }
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final title = titleController.text.trim();

                  final amount = double.tryParse(
                    amountController.text.trim().replaceAll(',', '.'),
                  );

                  if (title.isEmpty ||
                      amount == null ||
                      !amount.isFinite ||
                      amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid title and amount.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, {
                    'title': title,
                    'amount': amount,
                    'isIncome': isIncome,
                    'category': selectedCategory,
                  });
                },
                child: Text(
                  isEditing ? 'Update Transaction' : 'Save Transaction',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
