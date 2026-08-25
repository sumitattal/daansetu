-- DaanSetu V1.5.9 — Editable Receipts + immutable audit log

create table if not exists public.receipt_audit_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  receipt_id uuid not null references public.receipts(id) on delete restrict,
  receipt_number_snapshot text not null,
  edited_by uuid references auth.users(id) on delete set null,
  edited_by_name text not null,
  old_values jsonb not null,
  new_values jsonb not null,
  changed_fields jsonb not null,
  reason text,
  edited_at timestamptz not null default now()
);

create index if not exists receipt_audit_org_time_idx on public.receipt_audit_log(organization_id, edited_at desc);
create index if not exists receipt_audit_receipt_idx on public.receipt_audit_log(receipt_id, edited_at desc);

alter table public.receipt_audit_log enable row level security;

drop policy if exists "admins read receipt audit" on public.receipt_audit_log;
create policy "admins read receipt audit" on public.receipt_audit_log
for select using (public.is_org_admin(organization_id));

-- No client insert/update/delete policies are created. Audit rows are written only by the secure edit RPC.

create or replace function public.edit_receipt_with_audit(
  p_receipt_id uuid,
  p_receipt_number text,
  p_donor_name text,
  p_mobile text default null,
  p_pan text default null,
  p_amount numeric default null,
  p_payment_date date default current_date,
  p_mode text default 'Cash',
  p_cheque_no text default null,
  p_bank_name text default null,
  p_area_name text default null,
  p_is_80g boolean default false,
  p_reason text default null
)
returns public.receipts
language plpgsql
security definer
set search_path=public
as $$
declare
  rec public.receipts;
  pay public.payments;
  editor_name text;
  old_doc jsonb;
  new_doc jsonb;
  changes jsonb := '{}'::jsonb;
  normalized_mode text;
  db_mode public.payment_mode;
  new_status text;
  new_receipt_type public.receipt_type;
  updated_rec public.receipts;
begin
  select * into rec from public.receipts where id=p_receipt_id;
  if rec.id is null then raise exception 'Receipt not found'; end if;
  if not public.is_org_member(rec.organization_id) then raise exception 'Not authorized'; end if;

  select * into pay from public.payments where id=rec.payment_id;
  if pay.id is null then raise exception 'Payment record not found'; end if;

  select display_name into editor_name
  from public.organization_members
  where organization_id=rec.organization_id and user_id=auth.uid() and active=true;
  if editor_name is null then raise exception 'Active member profile not found'; end if;

  if coalesce(trim(p_receipt_number),'')='' then raise exception 'Receipt Number is required'; end if;
  if coalesce(trim(p_donor_name),'')='' then raise exception 'Donor Name is required'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Amount must be greater than zero'; end if;

  if exists(
    select 1 from public.receipts
    where organization_id=rec.organization_id
      and receipt_number=trim(p_receipt_number)
      and id<>rec.id
  ) then raise exception 'Receipt number already exists: %', trim(p_receipt_number); end if;

  normalized_mode:=lower(trim(coalesce(p_mode,'')));
  if normalized_mode in ('receipt given - payment pending','receipt given payment pending') then
    db_mode:='other'::public.payment_mode;
    new_status:='receipt_pending';
  elsif normalized_mode='cash' then db_mode:='cash'::public.payment_mode; new_status:='paid';
  elsif normalized_mode='upi' then db_mode:='upi'::public.payment_mode; new_status:='paid';
  elsif normalized_mode='bank' then db_mode:='bank'::public.payment_mode; new_status:='paid';
  elsif normalized_mode='cheque' then db_mode:='cheque'::public.payment_mode; new_status:='paid';
  else raise exception 'Invalid payment mode'; end if;

  if db_mode='cheque' and new_status='paid' and coalesce(trim(p_cheque_no),'')='' then
    raise exception 'Cheque Number is required for cheque payment';
  end if;

  new_receipt_type:=case when p_is_80g then '80g'::public.receipt_type else 'normal'::public.receipt_type end;

  old_doc:=jsonb_build_object(
    'receipt_number',rec.receipt_number,
    'donor_name',rec.donor_name_snapshot,
    'mobile',rec.donor_mobile_snapshot,
    'pan',rec.donor_pan_snapshot,
    'amount',pay.amount,
    'collection_date',pay.payment_date,
    'payment_mode',rec.payment_mode_snapshot,
    'payment_status',coalesce(pay.payment_status,'paid'),
    'cheque_number',rec.cheque_number_snapshot,
    'bank_name',rec.bank_name_snapshot,
    'area_name',rec.area_name_snapshot,
    'receipt_type',rec.receipt_type::text
  );

  update public.payments
  set amount=p_amount,
      payment_date=coalesce(p_payment_date,current_date),
      mode=db_mode,
      payment_status=new_status,
      is_80g=p_is_80g,
      transaction_reference=case when db_mode='cheque' and new_status='paid' then nullif(trim(p_cheque_no),'') else null end,
      bank_name=case when new_status='paid' then nullif(trim(p_bank_name),'') else null end
  where id=pay.id;

  update public.receipts
  set receipt_number=trim(p_receipt_number),
      donor_name_snapshot=trim(p_donor_name),
      donor_mobile_snapshot=nullif(trim(p_mobile),''),
      donor_pan_snapshot=nullif(upper(trim(p_pan)),''),
      area_name_snapshot=nullif(trim(p_area_name),''),
      amount_words_snapshot=public.indian_amount_words(p_amount),
      payment_mode_snapshot=case when new_status='receipt_pending' then 'Receipt Given - Payment Pending' else initcap(db_mode::text) end,
      cheque_number_snapshot=case when db_mode='cheque' and new_status='paid' then nullif(trim(p_cheque_no),'') else null end,
      bank_name_snapshot=case when new_status='paid' then nullif(trim(p_bank_name),'') else null end,
      receipt_type=new_receipt_type
  where id=rec.id
  returning * into updated_rec;

  new_doc:=jsonb_build_object(
    'receipt_number',updated_rec.receipt_number,
    'donor_name',updated_rec.donor_name_snapshot,
    'mobile',updated_rec.donor_mobile_snapshot,
    'pan',updated_rec.donor_pan_snapshot,
    'amount',p_amount,
    'collection_date',coalesce(p_payment_date,current_date),
    'payment_mode',updated_rec.payment_mode_snapshot,
    'payment_status',new_status,
    'cheque_number',updated_rec.cheque_number_snapshot,
    'bank_name',updated_rec.bank_name_snapshot,
    'area_name',updated_rec.area_name_snapshot,
    'receipt_type',updated_rec.receipt_type::text
  );

  if old_doc->'receipt_number' is distinct from new_doc->'receipt_number' then changes:=changes||jsonb_build_object('receipt_number',jsonb_build_object('from',old_doc->'receipt_number','to',new_doc->'receipt_number')); end if;
  if old_doc->'donor_name' is distinct from new_doc->'donor_name' then changes:=changes||jsonb_build_object('donor_name',jsonb_build_object('from',old_doc->'donor_name','to',new_doc->'donor_name')); end if;
  if old_doc->'mobile' is distinct from new_doc->'mobile' then changes:=changes||jsonb_build_object('mobile',jsonb_build_object('from',old_doc->'mobile','to',new_doc->'mobile')); end if;
  if old_doc->'pan' is distinct from new_doc->'pan' then changes:=changes||jsonb_build_object('pan',jsonb_build_object('from',old_doc->'pan','to',new_doc->'pan')); end if;
  if old_doc->'amount' is distinct from new_doc->'amount' then changes:=changes||jsonb_build_object('amount',jsonb_build_object('from',old_doc->'amount','to',new_doc->'amount')); end if;
  if old_doc->'collection_date' is distinct from new_doc->'collection_date' then changes:=changes||jsonb_build_object('collection_date',jsonb_build_object('from',old_doc->'collection_date','to',new_doc->'collection_date')); end if;
  if old_doc->'payment_mode' is distinct from new_doc->'payment_mode' then changes:=changes||jsonb_build_object('payment_mode',jsonb_build_object('from',old_doc->'payment_mode','to',new_doc->'payment_mode')); end if;
  if old_doc->'payment_status' is distinct from new_doc->'payment_status' then changes:=changes||jsonb_build_object('payment_status',jsonb_build_object('from',old_doc->'payment_status','to',new_doc->'payment_status')); end if;
  if old_doc->'cheque_number' is distinct from new_doc->'cheque_number' then changes:=changes||jsonb_build_object('cheque_number',jsonb_build_object('from',old_doc->'cheque_number','to',new_doc->'cheque_number')); end if;
  if old_doc->'bank_name' is distinct from new_doc->'bank_name' then changes:=changes||jsonb_build_object('bank_name',jsonb_build_object('from',old_doc->'bank_name','to',new_doc->'bank_name')); end if;
  if old_doc->'area_name' is distinct from new_doc->'area_name' then changes:=changes||jsonb_build_object('area_name',jsonb_build_object('from',old_doc->'area_name','to',new_doc->'area_name')); end if;
  if old_doc->'receipt_type' is distinct from new_doc->'receipt_type' then changes:=changes||jsonb_build_object('receipt_type',jsonb_build_object('from',old_doc->'receipt_type','to',new_doc->'receipt_type')); end if;

  if changes='{}'::jsonb then raise exception 'No receipt changes detected'; end if;

  insert into public.receipt_audit_log(
    organization_id,receipt_id,receipt_number_snapshot,edited_by,edited_by_name,
    old_values,new_values,changed_fields,reason
  ) values(
    rec.organization_id,rec.id,updated_rec.receipt_number,auth.uid(),editor_name,
    old_doc,new_doc,changes,nullif(trim(p_reason),'')
  );

  return updated_rec;
end $$;

grant execute on function public.edit_receipt_with_audit(uuid,text,text,text,text,numeric,date,text,text,text,text,boolean,text) to authenticated;
