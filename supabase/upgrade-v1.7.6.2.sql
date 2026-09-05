-- RYM_VARGANI V1.7.6.2
-- Ensure Receipt Given - Payment Pending settlements preserve the original receipt/payment date
-- and store the actual settlement date in payment_received_date.

create or replace function public.settle_pending_payment(
  p_payment_id uuid,
  p_mode public.payment_mode,
  p_cheque_no text default null,
  p_bank_name text default null,
  p_payment_date date default current_date
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  pay public.payments;
begin
  select * into pay from public.payments where id=p_payment_id;
  if pay.id is null then raise exception 'Payment record not found'; end if;
  if not public.is_org_member(pay.organization_id) then raise exception 'Not authorized'; end if;
  if coalesce(pay.payment_status,'paid')<>'receipt_pending' then
    raise exception 'This receipt is not payment-pending';
  end if;
  if p_mode='other' then raise exception 'Select Cash, UPI, Bank or Cheque'; end if;
  if p_mode='cheque' and coalesce(trim(p_cheque_no),'')='' then
    raise exception 'Cheque number is required';
  end if;

  update public.payments
  set mode=p_mode,
      payment_status='paid',
      -- IMPORTANT: do not overwrite payment_date here.
      -- payment_date remains the original receipt/collection date.
      payment_received_date=coalesce(p_payment_date,current_date),
      transaction_reference=case when p_mode='cheque' then nullif(trim(p_cheque_no),'') else null end,
      bank_name=nullif(trim(p_bank_name),'')
  where id=p_payment_id;

  update public.receipts
  set payment_mode_snapshot=initcap(p_mode::text),
      cheque_number_snapshot=case when p_mode='cheque' then nullif(trim(p_cheque_no),'') else null end,
      bank_name_snapshot=nullif(trim(p_bank_name),'')
  where payment_id=p_payment_id;
end $$;

grant execute on function public.settle_pending_payment(uuid,public.payment_mode,text,text,date) to authenticated;
