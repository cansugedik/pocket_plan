import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_plan/main.dart';
import 'package:pocket_plan/screens/backup_page.dart';
import 'package:pocket_plan/screens/csv_import_page.dart';
import 'package:pocket_plan/screens/monthly_summary_page.dart';
import 'package:pocket_plan/screens/home_page.dart';

void main() {
  const raw =
      '[{"title":"Saved","category":"Food","amount":5,"isIncome":false,"date":"2026-10-10","importId":"id-1"}]';
  for (final destination in [
    'Backup & restore',
    'Import CSV',
    'Monthly summary',
  ]) {
    testWidgets('App menu opens $destination without changing financial data', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'transactions': raw,
        'monthly_budget_2026_10': 10000,
      });
      await tester.pumpWidget(const PocketPlanApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('App menu'));
      await tester.pumpAndSettle();
      for (final label in [
        'Backup & restore',
        'Import CSV',
        'Monthly summary',
      ]) {
        expect(find.widgetWithText(MenuItemButton, label), findsOneWidget);
      }
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      final Type expected = switch (destination) {
        'Backup & restore' => BackupPage,
        'Import CSV' => CsvImportPage,
        _ => MonthlySummaryPage,
      };
      expect(find.byType(expected), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Pocket Plan'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('transactions'), raw);
      expect(prefs.getInt('monthly_budget_2026_10'), 10000);
    });
  }
  testWidgets('Menu works with keyboard on a narrow screen at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'transactions': raw});
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('App menu'));
    await tester.pumpAndSettle();
    final target = find.text('Monthly summary');
    await tester.ensureVisible(target);
    Focus.of(tester.element(target)).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(MonthlySummaryPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('transactions'),
      raw,
    );
  });
}
