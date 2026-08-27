# RYM_VARGANI V1.7.3.0 — Numeric Receipt Numbers + Daily Receipt Count

## Receipt numbering
- Automatic receipt numbers are now plain numbers only: `250`, `251`, `252`, `253`...
- The prefix such as `RYM/2026-27/` is no longer used.
- Leading zeros are removed.
- Existing prefixed auto-generated receipt numbers ending in 250 or higher are converted to their plain numeric value when safe.
- The next automatic receipt number is forced to **at least 253**.
- Duplicate receipt-number checking remains active for manual and automatic receipt numbers.

## Day-wise Report
- Added **Receipts Issued Today** summary card.
- It shows the count of receipts whose Receipt Date equals the selected Day-wise Report date.
- Both paid and Receipt Given - Payment Pending receipts are counted if issued on that date.

## Required
Run `supabase/upgrade-v1.7.3.0.sql` once.
The previous `upgrade-v1.7.2.8.sql` must also already be applied for clearing Payment Received Date when a receipt is changed to Payment Pending.
