# JSON backup export (version 1)

Open **Export backup → Prepare backup → Export JSON**. Export includes all
persisted transactions (including undated entries, categories and CSV import IDs)
and all monthly budgets in integer cents. Search and list filters do not apply.
The snapshot time is shown; prepare a fresh backup after changing data elsewhere.

The envelope contains `format: pocket-plan-backup`, `version: 1`, UTC `createdAt`,
`currency: EUR`, the original transaction objects, and `monthlyBudgetsCents`
keyed by their existing preferences keys. No storage keys or formats are changed.
Unrelated preferences are excluded. Missing, malformed or changing data aborts
preparation; exporting performs no preferences writes. Two reads detect changes,
but SharedPreferences does not provide an atomic multi-key database snapshot.

Web requests a JSON download. Android/iOS use the native share sheet (choose a
trusted file destination); desktop uses a save dialog. A requested export is not
proof that the user completed saving; check the destination. Mobile sharing uses
share_plus; file_selector handles desktop save selection. macOS selected-file
permission is read-write to allow saving only user-selected destinations.

The file is unencrypted and contains financial data. No automatic upload is
performed. Keep backups outside the repository. Restore is a separate future
feature; this step does not import or replace any data.

Tests use fake sources, mocked preferences and a fake exporter. Android/iOS
share sheets and desktop save dialogs still need device-level validation.
