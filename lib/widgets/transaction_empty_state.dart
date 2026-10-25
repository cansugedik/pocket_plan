import 'package:flutter/material.dart';

/// Scrolls with the transaction area so large text and the keyboard fit safely.
class TransactionEmptyState extends StatelessWidget {
  final bool hasConditions;
  final String title;
  final VoidCallback? onAction;

  const TransactionEmptyState({
    super.key,
    required this.hasConditions,
    required this.title,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.hasBoundedHeight && constraints.maxHeight > 120
            ? constraints.maxHeight - 120
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          hasConditions
                              ? Icons.search_off_rounded
                              : Icons.receipt_long_outlined,
                          size: 32,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasConditions
                          ? 'Clear the search and filters to show all saved transactions.'
                          : 'Add your first income or expense to start tracking your balance.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onAction,
                      icon: Icon(
                        hasConditions
                            ? Icons.filter_alt_off_outlined
                            : Icons.add_circle_outline,
                      ),
                      label: Text(
                        hasConditions
                            ? 'Clear search and filters'
                            : 'Add your first transaction',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
