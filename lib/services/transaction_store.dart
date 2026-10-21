import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/transaction.dart';

abstract class TransactionStorage {
  Future<String?> read();
  Future<bool> write(String value);
}

class PreferencesTransactionStorage implements TransactionStorage {
  static const key = 'transactions';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    // A failed legacy preferences write can still update its memory cache.
    await prefs.reload();
    return prefs.getString(key);
  }

  @override
  Future<bool> write(String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(key, value);
  }
}

/// Keeps the existing JSON format; refuses writes until a complete load succeeds.
class TransactionStore {
  final TransactionStorage storage;
  bool _loaded = false;
  bool _saving = false;
  String? _snapshot;

  TransactionStore({TransactionStorage? storage})
    : storage = storage ?? PreferencesTransactionStorage();

  Future<List<Transaction>> load({
    required List<Transaction> initialTransactions,
  }) async {
    _loaded = false;
    final raw = await storage.read();
    if (raw == null) {
      final initial = _encode(initialTransactions);
      if (!await storage.write(initial)) {
        throw StateError('Initial save failed');
      }
      _snapshot = initial;
      _loaded = true;
      return List.of(initialTransactions);
    }
    final decoded = jsonDecode(raw) as List;
    final records = decoded
        .map(
          (item) =>
              Transaction.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    _snapshot = raw;
    _loaded = true;
    return records;
  }

  Future<bool> save(List<Transaction> candidates) async {
    if (!_loaded || _saving) return false;
    _saving = true;
    try {
      if (await storage.read() != _snapshot) {
        _loaded = false;
        return false;
      }
      final next = _encode(candidates);
      if (!await storage.write(next)) {
        _loaded = false;
        return false;
      }
      _snapshot = next;
      return true;
    } catch (_) {
      _loaded = false;
      return false;
    } finally {
      _saving = false;
    }
  }

  String _encode(List<Transaction> records) =>
      jsonEncode(records.map((t) => t.toJson()).toList());
}
