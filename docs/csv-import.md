# Revolut CSV import

Open **Import CSV** in the home app bar, choose a file, review each selected row and category, then confirm the import. Choosing or previewing a file does not save transactions. Processing stays on the device. No bank connection is created.

## Supported first version

- UTF-8 English Revolut account CSV, up to 2 MB / 5000 data rows.
- Required columns: `Type`, `Completed Date`, `Description`, `Amount`, `Fee`, `Currency`, `State` (case insensitive).
- EUR, `COMPLETED`, `Card Payment` / `Card Refund`, zero fees.
- Completed calendar dates in `YYYY-MM-DD` format, optionally followed by a timestamp; statement calendar day is preserved.
- Signed amounts with decimal point, at most two decimal places. Negative values are expenses; positive values (including refunds) are income, rather than reducing category expenses.
- Transfers, non-EUR currencies, non-zero fees, pending/reverted transactions and invalid rows are skipped with reasons. No currency conversion or assumptions about unsupported rows.
- Unsupported headers are rejected; localised/other export formats require a verified adapter. Actual Revolut exports may differ. Confirm your file's header before using it.

`examples/revolut_sample.csv` contains fictional data for preview testing. Importing it will add fictional transactions, so stop at preview unless you want those records.

## Duplicate detection

Each imported transaction stores a local source identity alongside its existing fields. Editing a transaction preserves that identity. Re-importing unchanged source rows skips identities already stored, even after title/category/amount edits. Dates, original descriptions, signed amounts, type and available start timestamp/product contribute to the identity; running balance and CSV filename do not.

Repeated identical rows receive occurrence numbers, so legitimate repeated payments in one statement can remain separate. Without a bank transaction ID there is no perfect match across changed exports or partial overlapping files containing identical rows; review overlapping statements. Deleted imported records can be imported again. A manually entered matching title/date/amount is flagged and initially unchecked, not silently discarded.

Import appends to the existing transaction list only after explicit confirmation. It refuses a stale preview if persisted transactions differ from the home screen, preserves monthly budget keys, and reports save failures. No file contents or financial fields are logged.

File picking uses Flutter's `file_selector`; parsing uses `csv`. macOS receives only the user-selected file read permission. Android/iOS native builds still need their planned device validation.
