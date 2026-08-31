# RYM_VARGANI V1.7.4.6

- Fixed Super Admin receipt deletion when receipt audit history exists.
- Receipt audit history is preserved after deletion.
- Deleting a pending receipt also removes its pending payment entry.
- If another paid receipt exists for the same donor, the donor remains Collected.
- Added database-level protection: if a Receipt Given - Payment Pending entry exists, a second Collect attempt is blocked and the user must use Mark Payment.
- Deleted receipt numbers remain available for reuse.

## Required
Run `supabase/upgrade-v1.7.4.6.sql` in Supabase SQL Editor before using the fix.
