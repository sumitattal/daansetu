# RYM_VARGANI V1.7.3.6

## Receipt Number Usage Report
Added a new expandable report under Reports covering receipt numbers **101 to 400**.

It shows:
- Largest numeric receipt number generated in the 101–400 range.
- Count of used receipt numbers.
- Count of unused receipt-number gaps below the largest generated receipt.
- Full table from 101 to 400 with status:
  - Used
  - Unused
  - Not Yet Reached
- Used rows also show donor, receipt date, payment mode and amount.
- Filters:
  - All 101–400
  - Used Only
  - Unused Below Largest Only

No Supabase SQL change is required for V1.7.3.6.
All V1.7.3.5 fixes are retained.
