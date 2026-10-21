import 'package:flutter/material.dart';
import '../model/app_backup.dart';
import '../services/backup_service.dart';

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

  Future<void> prepare() async {
    setState(() {
      busy = true;
      backup = null;
      message = null;
    });
    try {
      final result = await (widget.service ?? BackupService()).create();
      if (mounted) setState(() => backup = result);
    } catch (_) {
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
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Export backup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Save a copy of all transactions, categories, dates, monthly budgets and CSV import IDs. Search and filters do not limit the backup.',
            ),
            const SizedBox(height: 16),
            const Text(
              'The JSON file is not encrypted and contains financial information. Keep it in a trusted location. Restoring backups is not available yet.',
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: busy ? null : prepare,
              child: Text(
                backup == null ? 'Prepare backup' : 'Prepare fresh backup',
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (backup != null) ...[
              const SizedBox(height: 16),
              Text(
                '${backup!.transactionCount} transactions · ${backup!.budgetCount} monthly budgets',
              ),
              Text('Snapshot: ${backup!.createdAt.toLocal()}'),
              const SizedBox(height: 16),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: busy ? null : () => save(buttonContext),
                  icon: const Icon(Icons.download),
                  label: const Text('Export JSON'),
                ),
              ),
            ],
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(message!, semanticsLabel: message),
              ),
          ],
        ),
      ),
    ),
  );
}
