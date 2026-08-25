-- DaanSetu V1.5.6 upgrade for an existing V1.5.x database.
-- Adds optional physical/manual receipt numbers and stores the donor route/area snapshot on each receipt.

alter table public.receipts
  add column if not exists area_name_snapshot text;

-- Remove the previous 7-argument RPC so the app always calls the V1.5.6 version.
drop function if exists public.record_donation(uuid,numeric,public.payment_mode,boolean,text,text,text);

create or replace function public.record_donation(
  p_donor_id uuid,
  p_amount numeric,
  p_mode public.payment_mode,
  p_is_80g boolean default false,
  p_pan text default null,
  p_cheque_no text default null,
  p_bank_name text default null,
  p_receipt_number text default null
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
  prefix text;
  area_name text;
  final_receipt_number text;
begin
  select * into d from public.donors where id=p_donor_id;
  if d.id is null or not public.is_org_member(d.organization_id) then raise exception 'Not authorized'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if p_mode='cheque' and coalesce(trim(p_cheque_no),'')='' then raise exception 'Cheque number is required'; end if;
  select * into org from public.organizations where id=d.organization_id;
  select name into area_name from public.routes where id=d.route_id;
  select display_name into collector from public.organization_members where organization_id=d.organization_id and user_id=auth.uid() and active=true;
  if collector is null then raise exception 'Active member profile not found'; end if;

  if coalesce(trim(p_pan),'')<>'' then update public.donors set pan=upper(trim(p_pan)) where id=d.id; d.pan:=upper(trim(p_pan)); end if;

  if coalesce(trim(p_receipt_number),'')<>'' then
    final_receipt_number:=trim(p_receipt_number);
    if exists(select 1 from public.receipts where organization_id=d.organization_id and receipt_number=final_receipt_number) then
      raise exception 'Receipt number already exists: %', final_receipt_number;
    end if;
  end if;

  insert into public.payments(organization_id,donor_id,received_by,amount,mode,transaction_reference,bank_name,is_80g)
  values(d.organization_id,d.id,auth.uid(),p_amount,p_mode,case when p_mode='cheque' then p_cheque_no else null end,p_bank_name,p_is_80g)
  returning * into pay;

  if final_receipt_number is null then
    insert into public.receipt_counters(organization_id,financial_year,receipt_type,current_number)
    values(d.organization_id,org.financial_year,rt,1)
    on conflict(organization_id,financial_year,receipt_type)
    do update set current_number=public.receipt_counters.current_number+1
    returning current_number into seq;
    prefix:=case when rt='80g' then org.receipt_80g_prefix else org.receipt_prefix end;
    final_receipt_number:=prefix||'/'||org.financial_year||'/'||lpad(seq::text,5,'0');
  end if;

  insert into public.receipts(organization_id,payment_id,receipt_type,receipt_number,donor_name_snapshot,donor_pan_snapshot,donor_mobile_snapshot,area_name_snapshot,amount_words_snapshot,payment_mode_snapshot,cheque_number_snapshot,bank_name_snapshot,collected_by_name_snapshot)
  values(d.organization_id,pay.id,rt,final_receipt_number,d.name,d.pan,d.mobile,area_name,public.indian_amount_words(p_amount),initcap(p_mode::text),case when p_mode='cheque' then p_cheque_no else null end,p_bank_name,collector)
  returning * into rec;
  return rec;
end $$;

grant execute on function public.record_donation(uuid,numeric,public.payment_mode,boolean,text,text,text,text) to authenticated;
