# RYM_VARGANI V1.7.6.0

Built on V1.7.5.9.

- Fixed Day-wise Report missing some normal paid receipts when `payment_received_date` is blank.
- Paid receipt collection date now uses Payment Received Date when available, otherwise falls back to the receipt/payment date.
- Previously pending receipts settled later continue to appear on the actual Payment Received Date.
- Unpaid Receipt Given - Payment Pending records remain excluded from collected totals and appear as pending on their receipt date.
- Added Bank Collection to Day-wise summary and included Bank in Total Day's Collection.
- Existing receipt/donor data is not modified.
- No Supabase migration required.
