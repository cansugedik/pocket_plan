import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/app_backup.dart';

abstract class RestoreStorage {
  Future<Map<String, Object?>> readAll();
  Future<bool> set(String key, Object value);
  Future<bool> remove(String key);
}

class PreferencesRestoreStorage implements RestoreStorage {
  @override
  Future<Map<String, Object?>> readAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return {for (final key in prefs.getKeys()) key: prefs.get(key)};
  }

  @override
  Future<bool> set(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) return prefs.setString(key, value);
    if (value is int) return prefs.setInt(key, value);
    throw StateError('Unsupported value');
  }

  @override
  Future<bool> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}

/// Serializes this app instance's storage operations. It is not a cross-tab lock.
class RestoreAccess {
  static Future<void>? _tail;
  static Future<T> exclusive<T>(Future<T> Function() action) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return (() async {
      if (previous != null) await previous;
      try {
        return await action();
      } finally {
        if (identical(_tail, released.future)) _tail = null;
        released.complete();
      }
    })();
  }

  static Future<T> guarded<T>(Future<T> Function() action) =>
      exclusive(() async {
        await BackupRestoreService().recoverPending();
        return action();
      });
}

class RestorePreview {
  final AppBackup backup;
  final Map<String, Object?> before;
  final Map<String, Object?> after;
  final int previousTransactions;
  final int previousBudgets;
  RestorePreview(
    this.backup,
    this.before,
    this.after,
    this.previousTransactions,
    this.previousBudgets,
  );
}

class BackupRestoreService {
  static const journalKey = 'pocket_plan_restore_pending_v1';
  static const recoveryKey = 'pocket_plan_before_restore_v1';
  final RestoreStorage storage;
  BackupRestoreService({RestoreStorage? storage})
    : storage = storage ?? PreferencesRestoreStorage();

  Map<String, Object?> _financial(Map<String, Object?> all) => {
    for (final entry in all.entries)
      if (entry.key == 'transactions' ||
          entry.key.startsWith('monthly_budget_'))
        entry.key: entry.value,
  };

  Future<void> _set(String key, Object value) async {
    if (!await storage.set(key, value)) throw StateError('Write failed');
  }

  Future<void> _replace(Map<String, Object?> values) async {
    final current = _financial(await storage.readAll());
    for (final key in current.keys.where((key) => !values.containsKey(key))) {
      if (!await storage.remove(key)) throw StateError('Remove failed');
    }
    for (final entry in values.entries) {
      if (current[entry.key] != entry.value) {
        await _set(entry.key, entry.value!);
      }
    }
    if (!mapEquals(values, _financial(await storage.readAll()))) {
      throw StateError('Verification failed');
    }
  }

  /// Pending journal means the previous restore never reached its commit point.
  /// Called under RestoreAccess before any production financial read/write.
  Future<void> recoverPending() async {
    final raw = (await storage.readAll())[journalKey];
    if (raw == null) return;
    if (raw is! String) throw StateError('Unreadable recovery journal');
    final before = Map<String, Object?>.from(jsonDecode(raw) as Map);
    if (!mapEquals(before, _financial(before))) {
      throw StateError('Invalid journal');
    }
    AppBackup.fromStoredValues(before, DateTime.now());
    await _replace(before);
    if (!await storage.remove(journalKey)) {
      throw StateError('Recovery not complete');
    }
  }

  Future<RestorePreview> preview(String contents) =>
      RestoreAccess.exclusive(() async {
        await recoverPending();
        final backup = AppBackup.parse(contents);
        final before = _financial(await storage.readAll());
        final current = AppBackup.fromStoredValues(before, DateTime.now());
        final json = jsonDecode(backup.contents) as Map;
        final after = <String, Object?>{
          'transactions': jsonEncode(json['transactions']),
          ...Map<String, Object?>.from(json['monthlyBudgetsCents'] as Map),
        };
        return RestorePreview(
          backup,
          Map.unmodifiable(before),
          Map.unmodifiable(after),
          current.transactionCount,
          current.budgetCount,
        );
      });

  Future<void> restore(
    RestorePreview preview,
  ) => RestoreAccess.exclusive(() async {
    await recoverPending();
    if (!mapEquals(preview.before, _financial(await storage.readAll()))) {
      throw StateError('Data changed since preview');
    }
    if (!mapEquals(preview.before, _financial(preview.before)) ||
        !mapEquals(preview.after, _financial(preview.after))) {
      throw StateError('Invalid restore keys');
    }
    // Validate again at the service boundary, before the first write.
    AppBackup.fromStoredValues(preview.before, DateTime.now());
    AppBackup.fromStoredValues(preview.after, DateTime.now());
    final before = jsonEncode(preview.before);
    await _set(recoveryKey, before);
    if ((await storage.readAll())[recoveryKey] != before) {
      throw StateError('Recovery copy verification failed');
    }
    await _set(journalKey, before);
    if ((await storage.readAll())[journalKey] != before) {
      throw StateError('Journal verification failed');
    }
    try {
      await _replace(preview.after);
      if (!await storage.remove(journalKey) ||
          (await storage.readAll()).containsKey(journalKey)) {
        throw StateError('Commit failed');
      }
    } catch (_) {
      // Keep journal if rollback also fails; subsequent access must retry recovery.
      await _set(journalKey, before);
      await recoverPending();
      rethrow;
    }
  });
}
