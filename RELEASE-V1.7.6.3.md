# RYM_VARGANI V1.7.6.3

Built on V1.7.6.2.

## Pending Receipts dashboard Excel
- The Dashboard `Pending Receipts` Excel now contains only genuine pending donors.
- Donors who already have a `Receipt Given - Payment Pending` receipt are excluded.
- This prevents the same donor from appearing in both Pending Donors and Receipt Given - Payment Pending workflows.

## Reports > Pending Donors Excel
- The same exclusion rule is applied to:
  - All Routes
  - All Routes Consolidated
  - Individual Route exports

## Receipt Given - Payment Pending
- Added search.
- Search works by:
  - Donor name
  - Mobile number
  - Receipt number
  - Area / route
  - Amount
- Shows matching result count while searching.

No Supabase migration is required for V1.7.6.3.
