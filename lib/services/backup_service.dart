import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../model/app_backup.dart';

abstract class BackupSource {
  Future<Map<String, Object?>> read();
}

class PreferencesBackupSource implements BackupSource {
  @override
  Future<Map<String, Object?>> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return {
      for (final key in prefs.getKeys())
        if (key == 'transactions' || key.startsWith('monthly_budget_'))
          key: prefs.get(key),
    };
  }
}

class BackupService {
  final BackupSource source;
  BackupService({BackupSource? source})
    : source = source ?? PreferencesBackupSource();

  Future<AppBackup> create() async {
    final first = await source.read();
    final backup = AppBackup.fromStoredValues(first, DateTime.now());
    if (!mapEquals(first, await source.read())) {
      throw StateError('Data changed during backup');
    }
    return backup;
  }
}

enum BackupExportResult { requested, cancelled }

typedef BackupExporter =
    Future<BackupExportResult> Function(AppBackup backup, Rect origin);

Future<BackupExportResult> exportBackup(AppBackup backup, Rect origin) async {
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(backup.contents)),
    mimeType: 'application/json',
    name: backup.fileName,
  );
  if (kIsWeb) {
    await file.saveTo(backup.fileName);
  } else if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [backup.fileName],
        sharePositionOrigin: origin,
      ),
    );
    if (result.status == ShareResultStatus.dismissed) {
      return BackupExportResult.cancelled;
    }
  } else {
    final location = await getSaveLocation(
      suggestedName: backup.fileName,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON backup', extensions: ['json']),
      ],
    );
    if (location == null) return BackupExportResult.cancelled;
    await file.saveTo(location.path);
  }
  return BackupExportResult.requested;
}
