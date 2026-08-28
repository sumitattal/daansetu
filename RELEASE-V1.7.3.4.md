# RYM_VARGANI V1.7.3.4

Fixed Super Admin receipt deletion.

Cause:
- The application displays database role `owner` as `Super Admin`.
- V1.7.3.3 database delete function checked for `Super Admin` text instead of also accepting `owner`.

Fix:
- `super_admin_delete_receipt()` now accepts database role `owner`.
- Delete Receipt remains restricted to Super Admin.
- Receipt and linked payment are deleted together.
- Existing deleted-number reuse logic from V1.7.3.3 remains unchanged.

Run `supabase/upgrade-v1.7.3.4.sql` in Supabase SQL Editor.
