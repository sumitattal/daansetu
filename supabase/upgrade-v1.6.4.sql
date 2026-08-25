-- RYM_VARGANI V1.6.4
-- Keeps receipt/collection date separate from the date money was actually received.
-- Day-wise paid collection must use payment_received_date.

alter table public.payments
  add column if not exists payment_received_date date;

-- Existing paid payments were historically recorded using payment_date as the received date.
update public.payments
set payment_received_date = payment_date
where payment_status = 'paid'
  and payment_received_date is null;

-- Pending receipts have not yet received money.
update public.payments
set payment_received_date = null
where payment_status = 'receipt_pending';

-- New immediately-paid collections should automatically use their collection date as received date.
create or replace function public.set_payment_received_date_on_paid()
returns trigger
language plpgsql
as $$
begin
  if new.payment_status = 'paid' and new.payment_received_date is null then
    new.payment_received_date := coalesce(new.payment_date,current_date);
  end if;
  return new;
end $$;

drop trigger if exists trg_set_payment_received_date_on_paid on public.payments;
create trigger trg_set_payment_received_date_on_paid
before insert on public.payments
for each row execute function public.set_payment_received_date_on_paid();

-- When a pending receipt is settled, preserve the original payment_date (receipt/collection date)
-- and save the user-selected date separately as payment_received_date.
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
  if pay.payment_status<>'receipt_pending' then raise exception 'This receipt is not payment-pending'; end if;
  if p_mode='other' then raise exception 'Select Cash, UPI, Bank or Cheque'; end if;
  if p_mode='cheque' and coalesce(trim(p_cheque_no),'')='' then raise exception 'Cheque number is required'; end if;

  update public.payments
  set mode=p_mode,
      payment_status='paid',
      payment_received_date=coalesce(p_payment_date,current_date),
      transaction_reference=case when p_mode='cheque' then p_cheque_no else null end,
      bank_name=p_bank_name
  where id=p_payment_id;

  update public.receipts
  set payment_mode_snapshot=initcap(p_mode::text),
      cheque_number_snapshot=case when p_mode='cheque' then p_cheque_no else null end,
      bank_name_snapshot=p_bank_name
  where payment_id=p_payment_id;
end $$;

grant execute on function public.settle_pending_payment(uuid,public.payment_mode,text,text,date) to authenticated;
