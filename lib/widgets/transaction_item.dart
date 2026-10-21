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

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: transactionKey,
      direction: enabled ? DismissDirection.endToStart : DismissDirection.none,

      // Silme onayı
      confirmDismiss: (direction) async {
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
      },

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
        child: ListTile(
          onTap: enabled ? onTap : null,
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(subtitle), Text(dateLabel)],
          ),
          isThreeLine: true,
          trailing: Text(
            amount,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
