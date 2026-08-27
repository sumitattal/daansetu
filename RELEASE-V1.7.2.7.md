# RYM_VARGANI V1.7.2.7 — Day-wise Mobile List Fix

- Fixed Day-wise Report mobile Activity values not being visible.
- Removed card-style presentation for individual activity records on mobile.
- Mobile activity is now a clean list with label/value rows separated by a thin divider.
- Keeps the requested order:
  Receipt → Donor → Mode of Payment → Amount → Receipt Date → Payment Received Date → Status.
- Desktop Day-wise Report remains a normal table.
- No Supabase migration required.
