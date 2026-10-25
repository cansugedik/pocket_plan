import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../services/backup_restore_service.dart';

typedef BackupPicker = Future<XFile?> Function();

class RestoreBackupPage extends StatefulWidget {
  final BackupRestoreService? service;
  final BackupPicker? picker;
  const RestoreBackupPage({super.key, this.service, this.picker});
  @override
  State<RestoreBackupPage> createState() => _RestoreBackupPageState();
}

class _RestoreBackupPageState extends State<RestoreBackupPage> {
  late final service = widget.service ?? BackupRestoreService();
  RestorePreview? preview;
  bool busy = false;
  String? message;

  Future<void> choose() async {
    setState(() {
      busy = true;
      preview = null;
      message = null;
    });
    try {
      final file =
          await (widget.picker ??
              () => openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'Pocket Plan backup',
                    extensions: ['json'],
                    mimeTypes: ['application/json'],
                    uniformTypeIdentifiers: ['public.json'],
                  ),
                ],
              ))();
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('Too large');
      }
      final result = await service.preview(
        utf8.decode(await file.readAsBytes()),
      );
      if (mounted) setState(() => preview = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Backup could not be opened. Choose a valid Pocket Plan version 1 EUR backup (up to 5 MB and 10,000 transactions), or reload the app if storage is unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    final selected = preview!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Replace saved data?'),
        content: Text(
          'Replace ${selected.previousTransactions} transactions and ${selected.previousBudgets} monthly budgets with ${selected.backup.transactionCount} transactions and ${selected.backup.budgetCount} budgets from this backup? This does not merge records. A local recovery copy will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace and restore'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await service.restore(selected);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          preview = null;
          message =
              'Restore did not complete. Reload the app to verify your data and retry automatic recovery if needed. If recovery has started, its recovery copy is retained locally. Choose the file again for a fresh preview.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Restore backup')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card.filled(
                      margin: EdgeInsets.zero,
                      color: colors.errorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: colors.onErrorContainer,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Restore replaces saved data',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Restore replaces all saved transactions and monthly budgets. Export a fresh backup first and keep it in a safe location. Only choose a file you trust.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: busy ? null : choose,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Choose JSON backup'),
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Reading or restoring backup',
                          ),
                        ),
                      ),
                    if (preview != null) ...[
                      const SizedBox(height: 16),
                      Card.filled(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Review the backup',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Current: ${preview!.previousTransactions} transactions · ${preview!.previousBudgets} budgets',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Backup: ${preview!.backup.transactionCount} transactions · ${preview!.backup.budgetCount} budgets',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created: ${preview!.backup.createdAt.toLocal()}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: busy ? null : restore,
                                child: const Text('Review restore'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              message!,
                              style: TextStyle(color: colors.onErrorContainer),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
