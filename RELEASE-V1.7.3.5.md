# RYM_VARGANI V1.7.3.5

- Fixes Edit Receipt showing Cash for existing UPI receipts.
- Canonical payment-mode display values are Cash, UPI, Bank, Cheque and Receipt Given - Payment Pending.
- Actual payment-mode changes persist through the edit RPC.
- Existing `Upi` receipt snapshots are normalized to `UPI`.
- Retains V1.7.3.4 Super Admin receipt-delete role fix.
- Retains V1.7.3.3 deleted receipt-number reuse.

Run `supabase/upgrade-v1.7.3.5.sql` in Supabase SQL Editor.
