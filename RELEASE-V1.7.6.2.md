# RYM_VARGANI V1.7.6.2

Built on V1.7.6.0.

## Day-wise report fix for settled pending receipts
- Normal paid receipt: Day-wise Report uses Receipt/Payment Date.
- Receipt Given - Payment Pending later marked paid: Day-wise Report uses the later of:
  - Receipt/Payment Date
  - Payment Received Date
- This supports both current and older settlement records.
- If an older Supabase function changed payment_date during settlement, that settlement date is still picked up.
- If payment_received_date is blank, the paid receipt is not lost from Day-wise Report.
- Date-wise dashboard graph uses the same effective-date rule.

## Supabase settlement correction
Run `supabase/upgrade-v1.7.6.2.sql`.
It ensures future Mark Payment actions:
- keep original payment_date unchanged
- save actual settlement date in payment_received_date
- update payment mode/status correctly

No receipt or donor is deleted or changed by the app update.
