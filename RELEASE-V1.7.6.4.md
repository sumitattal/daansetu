# RYM_VARGANI V1.7.6.4

## Pending donor consistency fix
The Dashboard Pending Receipts count, its downloaded Excel, the Pending tab, and Reports > Pending Donors Excel now use the same rule:

- Donor Status must be exactly `Pending`
- Donor must NOT have an active `Receipt Given - Payment Pending` receipt

Therefore the Dashboard count and downloaded Dashboard Excel row count will match.
Receipt Given - Payment Pending donors stay only in their separate payment-pending workflow.

The search added in V1.7.6.3 remains available.

No Supabase migration is required.
