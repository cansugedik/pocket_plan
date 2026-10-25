import 'package:flutter/material.dart';

class TransactionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String dateLabel;
  final String amount;
  final IconData icon;
  final Future<bool> Function() onDelete;
  final bool enabled;
  final VoidCallback onTap;
  final Key transactionKey;

  const TransactionItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.amount,
    required this.icon,
    required this.onDelete,
    this.enabled = true,
    required this.onTap,
    required this.transactionKey,
  });

  Future<bool> confirmDelete(BuildContext context) async {
    if (!enabled) return false;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text(
              'Are you sure you want to delete this transaction?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!context.mounted || !confirmed) return false;
    return onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: transactionKey,
      direction: enabled ? DismissDirection.endToStart : DismissDirection.none,

      confirmDismiss: (_) => confirmDelete(context),

      // Silme arka planı
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),

      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final theme = Theme.of(context);
                final stacked =
                    constraints.maxWidth < 480 ||
                    MediaQuery.textScalerOf(context).scale(16) > 22;
                final amountText = Text(
                  amount,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(child: Icon(icon)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Actions for $title',
                                enabled: enabled,
                                icon: const Icon(Icons.more_vert),
                                onSelected: (action) async {
                                  if (!enabled) return;
                                  if (action == 'edit') {
                                    onTap();
                                  } else {
                                    await confirmDelete(context);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(subtitle, style: theme.textTheme.bodyMedium),
                          Text(dateLabel, style: theme.textTheme.bodySmall),
                          if (stacked) ...[
                            const SizedBox(height: 8),
                            amountText,
                          ],
                        ],
                      ),
                    ),
                    if (!stacked) ...[
                      const SizedBox(width: 16),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * .35,
                        ),
                        child: amountText,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
