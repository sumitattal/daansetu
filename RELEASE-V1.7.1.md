# RYM_VARGANI V1.7.1 — Bulk Existing Receipt Upload

- Admin/Super Admin: **Upload All Existing Receipts** in Admin Panel → Google Drive Receipts.
- Generates calibrated PDF receipts one-by-one and uploads them to the configured Google Drive folder.
- Receipts that already have a Google Drive URL are skipped automatically.
- Safe to rerun after interruption; it resumes from receipts still missing a Drive URL.
- Live progress shows processed / total, current receipt, uploaded, failed and already-uploaded counts.
- Failed receipts can be retried by running the same operation again.
- Fixed receipt PDF generation during bulk jobs so each receipt is rendered from its own data instead of reusing a preview image.
- Includes the receipt search reliability fix: receipt no., donor, mobile, date, mode, collector, PAN, area and amount.
- No new Supabase migration beyond the existing V1.7.0 Google Drive migration.
