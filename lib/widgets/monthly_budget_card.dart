import 'package:flutter/material.dart';

import '../services/monthly_budget_store.dart';

class MonthlyBudgetCard extends StatefulWidget {
  final DateTime month;
  final double expenses;

  const MonthlyBudgetCard({
    super.key,
    required this.month,
    required this.expenses,
  });

  @override
  State<MonthlyBudgetCard> createState() => _MonthlyBudgetCardState();
}

class _MonthlyBudgetCardState extends State<MonthlyBudgetCard> {
  final store = MonthlyBudgetStore();
  int? budgetCents;
  bool loading = true;
  bool saving = false;
  bool loadFailed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadFailed = false;
    });
    try {
      final value = await store.load(widget.month);
      if (!mounted) return;
      setState(() {
        budgetCents = value;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadFailed = true;
        loading = false;
      });
    }
  }

  Future<void> editBudget() async {
    final amount = await showDialog<int>(
      context: context,
      builder: (context) =>
          _BudgetDialog(month: widget.month, budgetCents: budgetCents),
    );
    if (!mounted || amount == null) return;
    setState(() => saving = true);
    try {
      final saved = await store.save(widget.month, amount);
      if (!mounted) return;
      if (saved) {
        setState(() => budgetCents = amount);
      } else {
        showSaveError();
      }
    } catch (_) {
      if (mounted) showSaveError();
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void showSaveError() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Budget could not be saved. Please try again.'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final spentCents = (widget.expenses * 100).round();
    final remaining = (budgetCents ?? 0) - spentCents;
    final exceeded = remaining < 0;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly budget',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Text('Loading budget…')
            else if (loadFailed) ...[
              const Text('Budget could not be loaded.'),
              TextButton(onPressed: load, child: const Text('Retry')),
            ] else ...[
              if (budgetCents == null)
                const Text('No budget set for this month.')
              else ...[
                Text(
                  'Budget: €${(budgetCents! / 100).toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Spent: €${(spentCents / 100).toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: exceeded
                        ? colors.errorContainer
                        : colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        exceeded
                            ? Icons.warning_amber_rounded
                            : Icons.account_balance_wallet_outlined,
                        color: exceeded
                            ? colors.onErrorContainer
                            : colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${exceeded ? 'Over budget' : 'Remaining'}: €${(remaining.abs() / 100).toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: exceeded
                                ? colors.onErrorContainer
                                : colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  backgroundColor: colors.surfaceContainerHighest,
                  value: (spentCents / budgetCents!).clamp(0.0, 1.0),
                  semanticsLabel: 'Monthly budget used',
                  semanticsValue:
                      '${((spentCents / budgetCents!).clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                  color: exceeded ? Theme.of(context).colorScheme.error : null,
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                onPressed: saving ? null : editBudget,
                label: Text(
                  saving
                      ? 'Saving…'
                      : budgetCents == null
                      ? 'Set budget'
                      : 'Edit budget',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetDialog extends StatefulWidget {
  final DateTime month;
  final int? budgetCents;
  const _BudgetDialog({required this.month, this.budgetCents});
  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.budgetCents == null
          ? ''
          : (widget.budgetCents! / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      'Budget for ${MaterialLocalizations.of(context).formatMonthYear(widget.month)}',
    ),
    content: Form(
      key: formKey,
      child: TextFormField(
        key: const ValueKey('budget-amount'),
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Monthly expense budget (€)',
          errorMaxLines: 3,
        ),
        validator: (text) => MonthlyBudgetStore.parseCents(text ?? '') == null
            ? 'Enter a positive amount with up to 2 decimals.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (formKey.currentState!.validate()) {
            Navigator.pop(
              context,
              MonthlyBudgetStore.parseCents(controller.text),
            );
          }
        },
        child: const Text('Save budget'),
      ),
    ],
  );
}
