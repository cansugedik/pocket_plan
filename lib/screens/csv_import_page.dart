import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../model/transaction.dart';
import '../services/revolut_csv_import.dart';

class CsvImportPage extends StatefulWidget {
  final List<Transaction> existing;
  final Future<bool> Function(List<Transaction>) onImport;
  final Future<XFile?> Function()? chooseFile;
  const CsvImportPage({
    super.key,
    required this.existing,
    required this.onImport,
    this.chooseFile,
  });
  @override
  State<CsvImportPage> createState() => _CsvImportPageState();
}

class _CsvImportPageState extends State<CsvImportPage> {
  CsvImportPreview? preview;
  final selected = <int>{};
  final categories = <int, String>{};
  bool busy = false;
  String? error;
  String? filename;

  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
      preview = null;
      filename = null;
      selected.clear();
      categories.clear();
    });
    try {
      final file =
          await (widget.chooseFile?.call() ??
              openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'CSV',
                    extensions: ['csv'],
                    uniformTypeIdentifiers: [
                      'public.comma-separated-values-text',
                    ],
                  ),
                ],
              ));
      if (file == null) return;
      if (await file.length() > RevolutCsvImport.maxBytes) {
        throw const FormatException('Choose a CSV smaller than 2 MB.');
      }
      final bytes = await file.readAsBytes();
      final result = RevolutCsvImport().parse(
        utf8.decode(bytes),
        widget.existing,
      );
      if (!mounted) return;
      setState(() {
        filename = file.name;
        preview = result;
        selected.clear();
        categories.clear();
        for (var i = 0; i < result.rows.length; i++) {
          final row = result.rows[i];
          if (!row.duplicate && !row.possibleDuplicate) selected.add(i);
          categories[i] = row.transaction.category;
        }
      });
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The file could not be read. Choose a UTF-8 CSV file.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importSelected() async {
    final rows = preview;
    if (busy || rows == null || selected.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final transactions = selected.map((index) {
        final t = rows.rows[index].transaction;
        return Transaction(
          title: t.title,
          category: categories[index]!,
          amount: t.amount,
          icon: t.icon,
          isIncome: t.isIncome,
          date: t.date,
          importId: t.importId,
        );
      }).toList();
      final success = await widget.onImport(transactions);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context, transactions.length);
      } else {
        setState(
          () => error =
              'Import could not be saved. No records were added. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Import could not be saved. No records were added. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = preview;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Import Revolut CSV')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(24),
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
                            Icons.upload_file,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Import a statement',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Files are processed on this device. Nothing is uploaded.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card.filled(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Supported files',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'English Revolut account CSV, EUR only. Completed card payments and refunds with zero fees are supported. Transfers and other rows are skipped. Positive card amounts are recorded as income/refunds.',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Review every category and selection before importing. Suggested categories can be changed. Imported rows are recognised on re-import; matching manual records are only possible duplicates. Identical bank rows without an ID cannot be distinguished perfectly.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: busy ? null : pick,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose CSV file'),
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(
                        semanticsLabel: 'Reading or importing CSV',
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            error!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ),
                    ),
                  if (result != null) ...[
                    const SizedBox(height: 16),
                    Card.filled(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Review transactions',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              filename ?? '',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${selected.length} selected · ${result.rows.where((r) => r.duplicate).length} already imported · ${result.skipped.length} skipped',
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: busy || selected.isEmpty
                                  ? null
                                  : importSelected,
                              child: Text(
                                'Import ${selected.length} selected transactions',
                              ),
                            ),
                            if (result.rows.isEmpty) ...[
                              const SizedBox(height: 12),
                              const Text('No supported transactions found.'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < result.rows.length; i++)
                      buildRow(i, result.rows[i]),
                    if (result.skipped.isNotEmpty)
                      ExpansionTile(
                        title: Text('Skipped rows (${result.skipped.length})'),
                        children: result.skipped
                            .map((message) => ListTile(title: Text(message)))
                            .toList(),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRow(int index, CsvImportRow row) {
    final t = row.transaction;
    const expenses = [
      'Food',
      'Shopping',
      'Transport',
      'Bills',
      'Health',
      'Entertainment',
      'Other',
    ];
    const incomes = ['Salary', 'Freelance', 'Gift', 'Other'];
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selected.contains(index),
              onChanged: busy || row.duplicate
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        selected.add(index);
                      } else {
                        selected.remove(index);
                      }
                    }),
              title: Text(t.title),
              subtitle: Text(
                '${MaterialLocalizations.of(context).formatShortDate(t.date!)} · ${t.isIncome ? '+' : '-'}€${t.amount.toStringAsFixed(2)}\n${row.duplicate
                    ? 'Already imported'
                    : row.possibleDuplicate
                    ? 'Possible manual duplicate — unchecked'
                    : 'Row ${row.line}'}',
              ),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('${t.importId}-${categories[index]}'),
              initialValue: categories[index],
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Category'),
              items: (t.isIncome ? incomes : expenses)
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: busy || row.duplicate
                  ? null
                  : (value) => setState(() => categories[index] = value!),
            ),
          ],
        ),
      ),
    );
  }
}
