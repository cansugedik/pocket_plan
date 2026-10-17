import 'package:shared_preferences/shared_preferences.dart';

/// Budgets are stored in cents, separately from transaction data.
class MonthlyBudgetStore {
  String keyFor(DateTime month) =>
      'monthly_budget_${month.year}_${month.month.toString().padLeft(2, '0')}';

  Future<int?> load(DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyFor(month));
  }

  Future<bool> save(DateTime month, int cents) async {
    if (cents <= 0 || cents > 9007199254740991) {
      throw ArgumentError.value(cents, 'cents', 'Invalid budget');
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(keyFor(month), cents);
  }

  static int? parseCents(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final euros = int.tryParse(parts.first);
    if (euros == null || euros > 90071992547409) return null;
    final decimals = parts.length == 2
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;
    final cents = euros * 100 + decimals;
    return cents > 0 && cents <= 9007199254740991 ? cents : null;
  }
}
