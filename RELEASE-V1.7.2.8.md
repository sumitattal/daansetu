# RYM_VARGANI V1.7.2.8

- Mobile Day-wise Activity is now a true list/table, not cards.
- Exact column order:
  Receipt → Donor Name → Mode of Payment → Amount → Receipt Date → Payment Received Date → Status.
- On small screens the list scrolls horizontally so no values are hidden.
- When an edited receipt changes from Cash / UPI / Bank / Cheque to **Receipt Given - Payment Pending**, `payment_received_date` is cleared automatically.
- This prevents the pending receipt from continuing to appear as paid collection on its old payment-received date.
- Run `supabase/upgrade-v1.7.2.8.sql`.
