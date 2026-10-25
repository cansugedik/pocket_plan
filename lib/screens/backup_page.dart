import 'package:flutter/material.dart';
import '../model/app_backup.dart';
import '../services/backup_service.dart';
import 'restore_backup_page.dart';

class BackupPage extends StatefulWidget {
  final BackupService? service;
  final BackupExporter? exporter;
  const BackupPage({super.key, this.service, this.exporter});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  AppBackup? backup;
  bool busy = false;
  String? message;
  bool messageIsError = false;

  Future<void> prepare() async {
    setState(() {
      busy = true;
      backup = null;
      message = null;
      messageIsError = false;
    });
    try {
      final result = await (widget.service ?? BackupService()).create();
      if (mounted) setState(() => backup = result);
    } catch (_) {
      messageIsError = true;
      if (mounted) {
        setState(
          () => message =
              'Backup could not be prepared. Your saved data has not been changed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      busy = true;
      message = null;
      messageIsError = false;
    });
    try {
      final result = await (widget.exporter ?? exportBackup)(backup!, origin);
      if (mounted) {
        setState(
          () => message = result == BackupExportResult.cancelled
              ? 'Export cancelled. Your saved data has not been changed.'
              : 'Export requested. Check your downloads or chosen destination for the JSON file.',
        );
      }
    } catch (_) {
      messageIsError = true;
      if (mounted) {
        setState(
          () => message =
              'Export failed. Please try again. Your saved data has not been changed.',
        );
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
        appBar: AppBar(title: const Text('Export backup')),
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
                      color: colors.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.save_alt,
                              color: colors.onPrimaryContainer,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Keep a copy of your data',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Save a copy of all transactions, categories, dates, monthly budgets and CSV import IDs. Search and filters do not limit the backup.',
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'The JSON file is not encrypted and contains financial information. Keep it in a trusted location.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: busy ? null : prepare,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: Text(
                        backup == null
                            ? 'Prepare backup'
                            : 'Prepare fresh backup',
                      ),
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Preparing or exporting backup',
                          ),
                        ),
                      ),
                    if (backup != null) ...[
                      const SizedBox(height: 16),
                      Card.filled(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Backup ready',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${backup!.transactionCount} transactions · ${backup!.budgetCount} monthly budgets',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Snapshot: ${backup!.createdAt.toLocal()}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              Builder(
                                builder: (buttonContext) => FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => save(buttonContext),
                                  icon: const Icon(Icons.download),
                                  label: const Text('Export JSON'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: messageIsError
                                ? colors.errorContainer
                                : colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message!,
                            style: TextStyle(
                              color: messageIsError
                                  ? colors.onErrorContainer
                                  : colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Card.outlined(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Restore an existing backup',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Review the backup before replacing saved transactions and budgets.',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final restored =
                                          await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RestoreBackupPage(),
                                            ),
                                          );
                                      if (!mounted) return;
                                      setState(() => backup = null);
                                      if (restored == true && context.mounted) {
                                        Navigator.pop(context, true);
                                      }
                                    },
                              icon: const Icon(Icons.restore),
                              label: const Text('Restore from JSON'),
                            ),
                          ],
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
