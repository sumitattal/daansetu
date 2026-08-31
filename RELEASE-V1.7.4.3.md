# RYM_VARGANI V1.7.4.3

Build fix for V1.7.4.2.

- Fixed recursive `donorPendingAmount` expression introduced during the V1.7.4.2 replacement.
- Added explicit `: number` return type.
- Retains the V1.7.4.2 business rule:
  - no collection this year = Pending
  - any paid collection this year = Collected
  - reduced donations are reported separately under Donors with Reduced Donation.
- No new Supabase SQL migration is required.
