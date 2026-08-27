-- RYM_VARGANI V1.7.3.0
-- Plain numeric receipt numbers. Existing current-format auto receipts are converted
-- from values such as RYM/2026-27/00250 to 250. The next generated number is at least 253.

with candidates as (
  select r.id,
         r.organization_id,
         (regexp_match(r.receipt_number, '/([0-9]+)$'))[1]::bigint::text as new_number
  from public.receipts r
  where r.receipt_number ~ '/[0-9]+$'
), safe as (
  select c.*
  from candidates c
  where c.new_number is not null
    and c.new_number::bigint >= 250
    and not exists (
      select 1 from public.receipts x
      where x.organization_id=c.organization_id
        and x.id<>c.id
        and x.receipt_number=c.new_number
    )
)
update public.receipts r
set receipt_number=s.new_number
from safe s
where r.id=s.id;

update public.receipt_counters
set current_number=greatest(current_number,252)
where current_number<252;

create or replace function public.record_donation(
  p_donor_id uuid,
  p_amount numeric,
  p_mode public.payment_mode,
  p_is_80g boolean default false,
  p_pan text default null,
  p_cheque_no text default null,
  p_bank_name text default null,
  p_receipt_number text default null,
  p_payment_date date default current_date,
  p_payment_pending boolean default false
)
returns public.receipts
language plpgsql security definer set search_path=public as $$
declare
  d public.donors;
  org public.organizations;
  collector text;
  pay public.payments;
  rec public.receipts;
  rt public.receipt_type := case when p_is_80g then '80g'::public.receipt_type else 'normal'::public.receipt_type end;
  seq integer;
  area_name text;
  final_receipt_number text;
  mode_snapshot text;
begin
  select * into d from public.donors where id=p_donor_id and active=true;
  if d.id is null or not public.is_org_member(d.organization_id) then raise exception 'Not authorized'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if not p_payment_pending and p_mode='cheque' and coalesce(trim(p_cheque_no),'')='' then raise exception 'Cheque number is required'; end if;

  select * into org from public.organizations where id=d.organization_id;
  select name into area_name from public.routes where id=d.route_id;
  select display_name into collector from public.organization_members where organization_id=d.organization_id and user_id=auth.uid() and active=true;
  if collector is null then raise exception 'Active member profile not found'; end if;

  if coalesce(trim(p_pan),'')<>'' then
    update public.donors set pan=upper(trim(p_pan)), updated_at=now() where id=d.id;
    d.pan:=upper(trim(p_pan));
  end if;

  insert into public.payments(
    organization_id,donor_id,received_by,amount,mode,transaction_reference,bank_name,payment_date,is_80g,payment_status
  ) values(
    d.organization_id,d.id,auth.uid(),p_amount,p_mode,
    case when p_mode='cheque' and not p_payment_pending then p_cheque_no else null end,
    case when not p_payment_pending then p_bank_name else null end,
    coalesce(p_payment_date,current_date),p_is_80g,
    case when p_payment_pending then 'receipt_pending' else 'paid' end
  ) returning * into pay;

  if coalesce(trim(p_receipt_number),'')<>'' then
    final_receipt_number:=trim(p_receipt_number);
    if exists(select 1 from public.receipts where organization_id=d.organization_id and receipt_number=final_receipt_number) then
      raise exception 'Receipt number already exists: %', final_receipt_number;
    end if;
  else
    insert into public.receipt_counters(organization_id,financial_year,receipt_type,current_number)
    values(d.organization_id,org.financial_year,rt,253)
    on conflict(organization_id,financial_year,receipt_type)
    do update set current_number=greatest(public.receipt_counters.current_number+1,253)
    returning current_number into seq;
    final_receipt_number:=seq::text;
    while exists(select 1 from public.receipts where organization_id=d.organization_id and receipt_number=final_receipt_number) loop
      seq:=seq+1;
      update public.receipt_counters set current_number=seq
      where organization_id=d.organization_id and financial_year=org.financial_year and receipt_type=rt;
      final_receipt_number:=seq::text;
    end loop;
  end if;

  mode_snapshot:=case when p_payment_pending then 'Receipt Given - Payment Pending' else initcap(p_mode::text) end;

  insert into public.receipts(
    organization_id,payment_id,receipt_type,receipt_number,donor_name_snapshot,donor_pan_snapshot,donor_mobile_snapshot,
    area_name_snapshot,amount_words_snapshot,payment_mode_snapshot,cheque_number_snapshot,bank_name_snapshot,collected_by_name_snapshot
  ) values(
    d.organization_id,pay.id,rt,final_receipt_number,d.name,d.pan,d.mobile,area_name,
    public.indian_amount_words(p_amount),mode_snapshot,
    case when p_mode='cheque' and not p_payment_pending then p_cheque_no else null end,
    case when not p_payment_pending then p_bank_name else null end,
    collector
  ) returning * into rec;

  return rec;
end $$;



grant execute on function public.record_donation(uuid,numeric,public.payment_mode,boolean,text,text,text,text,date,boolean) to authenticated;
