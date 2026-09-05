# RYM_VARGANI V1.7.6.5

Verified correction for Dashboard Pending Receipts Excel.

The downloaded Excel now uses exactly the same donor rule as the Dashboard Pending Receipts count:
- donor status is `Pending`
- donor does NOT have an active `Receipt Given - Payment Pending` receipt

This specifically excludes donors such as Ashish Chandak once a payment-pending receipt has already been issued.

The same exclusion is also applied to the Pending tab and Reports > Pending Donors Excel.

No Supabase migration is required.
