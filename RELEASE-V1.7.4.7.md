# RYM_VARGANI V1.7.4.7

## Duplicate receipt prevention improved

Before opening Collect for a donor, the app now checks whether any receipt already exists for that donor.

If a receipt exists, Collect is blocked and the user sees:
- Receipt number
- Payment method
- Name of the user/collector who created the existing receipt
- Instruction not to create another receipt
- For Receipt Given - Payment Pending, instruction to use Mark Payment.

This applies regardless of the payment method of the existing receipt.

No new Supabase SQL migration is required beyond the V1.7.4.6 migration.
