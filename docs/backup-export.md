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
performed. Keep backups outside the repository. Restore is available through **Restore from JSON**; see below.

Tests use fake sources, mocked preferences and a fake exporter. Android/iOS
share sheets and desktop save dialogs still need device-level validation.

## Restore (replace, not merge)

Open **Export backup → Restore from JSON → Choose JSON backup**. Check the
current/backup transaction and budget counts and the creation date, then choose
**Review restore**. **Cancel** does not restore anything. **Replace and restore**
replaces all transactions and budgets, including removing budgets absent from the
backup. Other preferences remain untouched. Categories, dates and import IDs are
preserved; no migration of existing transaction/budget keys or formats occurs.
After success the home screen reloads and clears search/list filters.

Only complete Pocket Plan version 1 EUR envelopes are accepted (5 MB, 10,000
transactions maximum). Files are decoded locally; no upload occurs. Invalid
records, unsupported versions and changes to current data since preview abort the
restore. Export a fresh backup first. Import does not evaluate any file content
as executable code.

A copy of the original financial preferences is verified under
`pocket_plan_before_restore_v1`. The latest attempted restore replaces that copy;
it is not a backup history or an undo button. Before changing financial keys a
verified journal is stored under `pocket_plan_restore_pending_v1`. Journal removal
is the commit point. Failure triggers rollback. If interrupted, the next financial
read/write retries rollback first. Recovery failure blocks normal access; the
journal is retained for retry. Corrupt journals fail closed without overwriting
financial data. Production transaction, budget and export accesses use this guard.
Export can therefore perform recovery writes when an interrupted restore exists.

Operations are serialized within one application instance. SharedPreferences is
not an atomic/durable database and does not provide a cross-tab lock. Do not edit
or restore simultaneously in multiple tabs. Disk, OS or browser storage loss
cannot be prevented by this journal; keep an external JSON backup. No guarantee
of transaction-level crash durability is claimed.

Tests use fault injection at each restore mutation, pending-journal restart
simulation, read-only preview, invalid files, cancellations and fake preferences.
Real user data is not restored during testing. Native file-picker behavior still
requires Android/iOS device validation.
