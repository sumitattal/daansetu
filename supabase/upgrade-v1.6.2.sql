-- RYM_VARGANI V1.6.2
-- Fix payment-mode display mismatch by syncing receipt snapshots from the
-- authoritative payment record for all existing receipts.

update public.receipts r
set payment_mode_snapshot = case
  when coalesce(p.payment_status, 'paid') = 'receipt_pending'
    then 'Receipt Given - Payment Pending'
  else initcap(p.mode::text)
end,
cheque_number_snapshot = case
  when p.mode = 'cheque' and coalesce(p.payment_status, 'paid') = 'paid'
    then p.transaction_reference
  else null
end,
bank_name_snapshot = case
  when coalesce(p.payment_status, 'paid') = 'paid'
    then p.bank_name
  else null
end
from public.payments p
where r.payment_id = p.id;
