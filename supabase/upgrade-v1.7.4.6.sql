-- RYM_VARGANI V1.7.4.6
-- Fix receipt deletion when audit history exists and prevent a second collection
-- while a Receipt Given - Payment Pending entry is still open.

-- Preserve receipt edit history even if a Super Admin deletes the receipt.
alter table public.receipt_audit_log
  drop constraint if exists receipt_audit_log_receipt_id_fkey;

alter table public.receipt_audit_log
  alter column receipt_id drop not null;

alter table public.receipt_audit_log
  add constraint receipt_audit_log_receipt_id_fkey
  foreign key (receipt_id) references public.receipts(id) on delete set null;

create or replace function public.super_admin_delete_receipt(p_receipt_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  rec public.receipts;
  member_role text;
begin
  select * into rec from public.receipts where id=p_receipt_id;
  if rec.id is null then raise exception 'Receipt not found'; end if;

  select role::text into member_role
  from public.organization_members
  where organization_id=rec.organization_id
    and user_id=auth.uid()
    and active=true
  limit 1;

  if coalesce(lower(trim(member_role)),'') not in
     ('owner','super admin','super_admin','superadmin') then
    raise exception 'Only Super Admin can delete receipts';
  end if;

  -- Audit rows are retained; their receipt_id becomes NULL by FK rule.
  delete from public.receipts where id=rec.id;
  delete from public.payments where id=rec.payment_id;
end
$$;

grant execute on function public.super_admin_delete_receipt(uuid) to authenticated;

-- Prevent accidental duplicate collection if a pending receipt already exists.
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

  -- A pending receipt must be settled with Mark Payment, not collected again.
  if exists(
    select 1
    from public.payments p
    join public.receipts r on r.payment_id=p.id
    where p.donor_id=d.id
      and p.organization_id=d.organization_id
      and p.payment_status='receipt_pending'
  ) then
    raise exception 'A Receipt Given - Payment Pending entry already exists for this donor. Use Mark Payment instead of Collect.';
  end if;

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
    -- Reuse the smallest free receipt number from 250 upward.
    seq:=250;
    while exists(
      select 1 from public.receipts
      where organization_id=d.organization_id and receipt_number=seq::text
    ) loop
      seq:=seq+1;
    end loop;
    final_receipt_number:=seq::text;
    insert into public.receipt_counters(organization_id,financial_year,receipt_type,current_number)
    values(d.organization_id,org.financial_year,rt,seq)
    on conflict(organization_id,financial_year,receipt_type)
    do update set current_number=excluded.current_number;
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
