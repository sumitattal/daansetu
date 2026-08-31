-- DaanSetu V1.5 — Live Database schema for Supabase
create extension if not exists pgcrypto;

do $$ begin create type public.member_role as enum ('owner','admin','treasurer','volunteer','viewer'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_mode as enum ('cash','upi','bank','cheque','other'); exception when duplicate_object then null; end $$;
do $$ begin create type public.receipt_type as enum ('normal','80g'); exception when duplicate_object then null; end $$;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_mr text,
  address text,
  pan text,
  registration_12a text,
  registration_80g text,
  csr_number text,
  receipt_prefix text not null default 'RYM',
  receipt_80g_prefix text not null default 'RYM/80G',
  financial_year text not null default '2026-27',
  created_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null default 'volunteer',
  display_name text not null,
  mobile text,
  login_name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id),
  unique (organization_id, login_name)
);

create table if not exists public.routes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists public.donors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  route_id uuid references public.routes(id) on delete set null,
  name text not null,
  contact_person text,
  mobile text,
  pan text,
  address text,
  current_expected_amount numeric(12,2) not null default 0 check (current_expected_amount >= 0),
  last_year_donation numeric(12,2) not null default 0 check (last_year_donation >= 0),
  last_year_receipt_number text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists donors_org_route_idx on public.donors(organization_id, route_id);
create index if not exists donors_org_name_idx on public.donors(organization_id, name);

create table if not exists public.organization_people (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  mobile text not null,
  birth_date date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, mobile)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  donor_id uuid not null references public.donors(id) on delete restrict,
  received_by uuid references auth.users(id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  mode public.payment_mode not null,
  transaction_reference text,
  bank_name text,
  payment_date date not null default current_date,
  is_80g boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.receipt_counters (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  financial_year text not null,
  receipt_type public.receipt_type not null,
  current_number integer not null default 0,
  primary key (organization_id, financial_year, receipt_type)
);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  payment_id uuid not null unique references public.payments(id) on delete restrict,
  receipt_type public.receipt_type not null,
  receipt_number text not null,
  donor_name_snapshot text not null,
  donor_pan_snapshot text,
  donor_mobile_snapshot text,
  area_name_snapshot text,
  amount_words_snapshot text not null,
  payment_mode_snapshot text not null,
  cheque_number_snapshot text,
  bank_name_snapshot text,
  collected_by_name_snapshot text not null,
  issued_at timestamptz not null default now(),
  unique (organization_id, receipt_number)
);

create or replace function public.is_org_member(org uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.organization_members m where m.organization_id=org and m.user_id=auth.uid() and m.active=true);
$$;

create or replace function public.is_org_admin(org uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.organization_members m where m.organization_id=org and m.user_id=auth.uid() and m.active=true and m.role in ('owner','admin'));
$$;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.routes enable row level security;
alter table public.donors enable row level security;
alter table public.organization_people enable row level security;
alter table public.payments enable row level security;
alter table public.receipt_counters enable row level security;
alter table public.receipts enable row level security;

drop policy if exists "members read organizations" on public.organizations;
create policy "members read organizations" on public.organizations for select using (public.is_org_member(id));

drop policy if exists "members read memberships" on public.organization_members;
create policy "members read memberships" on public.organization_members for select using (public.is_org_member(organization_id));

drop policy if exists "admin update memberships" on public.organization_members;
create policy "admin update memberships" on public.organization_members for update using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

drop policy if exists "members read routes" on public.routes;
create policy "members read routes" on public.routes for select using (public.is_org_member(organization_id));
drop policy if exists "admins write routes" on public.routes;
create policy "admins write routes" on public.routes for all using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

drop policy if exists "members read donors" on public.donors;
create policy "members read donors" on public.donors for select using (public.is_org_member(organization_id));
drop policy if exists "members insert donors" on public.donors;
create policy "members insert donors" on public.donors for insert with check (public.is_org_member(organization_id));
drop policy if exists "members update donors" on public.donors;
drop policy if exists "admins update donors" on public.donors;
create policy "admins update donors" on public.donors for update using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

-- Any active organization user may change a donor's route, but this RPC changes no other donor field.
create or replace function public.change_donor_route(p_donor_id uuid, p_route_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  d_org uuid;
  r_org uuid;
begin
  select organization_id into d_org from public.donors where id=p_donor_id and active=true;
  if d_org is null then raise exception 'Donor not found'; end if;
  if not public.is_org_member(d_org) then raise exception 'Not authorized'; end if;
  if p_route_id is not null then
    select organization_id into r_org from public.routes where id=p_route_id and active=true;
    if r_org is null or r_org<>d_org then raise exception 'Invalid route'; end if;
  end if;
  update public.donors set route_id=p_route_id, updated_at=now() where id=p_donor_id;
end $$;

-- Admin-only soft removal preserves historical payments and receipts.
create or replace function public.admin_remove_donor(p_donor_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  d_org uuid;
begin
  select organization_id into d_org from public.donors where id=p_donor_id and active=true;
  if d_org is null then raise exception 'Donor not found'; end if;
  if not public.is_org_admin(d_org) then raise exception 'Only Admin or Super Admin can delete a donor'; end if;
  update public.donors set active=false, updated_at=now() where id=p_donor_id;
end $$;

grant execute on function public.change_donor_route(uuid,uuid) to authenticated;
grant execute on function public.admin_remove_donor(uuid) to authenticated;

drop policy if exists "members read people" on public.organization_people;
create policy "members read people" on public.organization_people for select using (public.is_org_member(organization_id));
drop policy if exists "admins write people" on public.organization_people;
create policy "admins write people" on public.organization_people for all using (public.is_org_admin(organization_id)) with check (public.is_org_admin(organization_id));

drop policy if exists "members read payments" on public.payments;
create policy "members read payments" on public.payments for select using (public.is_org_member(organization_id));
drop policy if exists "members read receipts" on public.receipts;
create policy "members read receipts" on public.receipts for select using (public.is_org_member(organization_id));

-- Converts an integer amount to Indian-system English words for receipt snapshots.
create or replace function public.say_999(x bigint)
returns text language plpgsql immutable as $$
declare
  y bigint := x;
  z text := '';
  ones text[] := array['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
  tens text[] := array['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
begin
  if y>=100 then z:=z||ones[(y/100)::int+1]||' Hundred '; y:=y%100; end if;
  if y>=20 then z:=z||tens[(y/10)::int+1]||' '; y:=y%10;
  elsif y>0 then z:=z||ones[y::int+1]||' '; y:=0; end if;
  if y>0 then z:=z||ones[y::int+1]||' '; end if;
  return trim(z);
end $$;

create or replace function public.indian_amount_words(p_amount numeric)
returns text language plpgsql immutable as $$
declare
  n bigint := floor(abs(p_amount));
  result text := '';
  part bigint;
begin
  if n=0 then return 'Zero Rupees Only'; end if;
  part:=n/10000000; if part>0 then result:=result||public.say_999(part)||' Crore '; n:=n%10000000; end if;
  part:=n/100000; if part>0 then result:=result||public.say_999(part)||' Lakh '; n:=n%100000; end if;
  part:=n/1000; if part>0 then result:=result||public.say_999(part)||' Thousand '; n:=n%1000; end if;
  if n>0 then result:=result||public.say_999(n)||' '; end if;
  return trim(result)||' Rupees Only';
end $$;

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

  insert into public.payments(organization_id,donor_id,received_by,amount,mode,transaction_reference,bank_name,is_80g)
  values(d.organization_id,d.id,auth.uid(),p_amount,p_mode,case when p_mode='cheque' then p_cheque_no else null end,p_bank_name,p_is_80g)
  returning * into pay;

  if coalesce(trim(p_receipt_number),'')<>'' then
    final_receipt_number:=trim(p_receipt_number);
    if exists(select 1 from public.receipts where organization_id=d.organization_id and receipt_number=final_receipt_number) then
      raise exception 'Receipt number already exists: %', final_receipt_number;
    end if;
  else
    insert into public.receipt_counters(organization_id,financial_year,receipt_type,current_number)
    values(d.organization_id,org.financial_year,rt,250)
    on conflict(organization_id,financial_year,receipt_type)
    do update set current_number=greatest(public.receipt_counters.current_number+1,250)
    returning current_number into seq;
    prefix:=case when rt='80g' then org.receipt_80g_prefix else org.receipt_prefix end;
    final_receipt_number:=prefix||'/'||org.financial_year||'/'||lpad(seq::text,5,'0');
    while exists(select 1 from public.receipts where organization_id=d.organization_id and receipt_number=final_receipt_number) loop
      seq:=seq+1;
      update public.receipt_counters set current_number=seq
      where organization_id=d.organization_id and financial_year=org.financial_year and receipt_type=rt;
      final_receipt_number:=prefix||'/'||org.financial_year||'/'||lpad(seq::text,5,'0');
    end loop;
  end if;

  insert into public.receipts(organization_id,payment_id,receipt_type,receipt_number,donor_name_snapshot,donor_pan_snapshot,donor_mobile_snapshot,area_name_snapshot,amount_words_snapshot,payment_mode_snapshot,cheque_number_snapshot,bank_name_snapshot,collected_by_name_snapshot)
  values(d.organization_id,pay.id,rt,final_receipt_number,d.name,d.pan,d.mobile,area_name,public.indian_amount_words(p_amount),initcap(p_mode::text),case when p_mode='cheque' then p_cheque_no else null end,p_bank_name,collector)
  returning * into rec;
  return rec;
end $$;

grant execute on function public.record_donation(uuid,numeric,public.payment_mode,boolean,text,text,text,text) to authenticated;


-- DaanSetu V1.5.8 additions for fresh installs
-- DaanSetu V1.5.8 upgrade
-- Adds donor Reference, collection date, receipt-issued/payment-pending workflow,
-- and settlement of those pending receipts.

alter table public.donors
  add column if not exists reference text;

alter table public.payments
  add column if not exists payment_status text not null default 'paid';

alter table public.payments
  drop constraint if exists payments_payment_status_check;
alter table public.payments
  add constraint payments_payment_status_check
  check (payment_status in ('paid','receipt_pending'));

-- Replace the previous donation RPC with a version that accepts collection date
-- and can issue a receipt while keeping payment pending.
drop function if exists public.record_donation(uuid,numeric,public.payment_mode,boolean,text,text,text,text);

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
  prefix text;
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
    values(d.organization_id,org.financial_year,rt,250)
    on conflict(organization_id,financial_year,receipt_type)
    do update set current_number=greatest(public.receipt_counters.current_number+1,250)
    returning current_number into seq;
    prefix:=case when rt='80g' then org.receipt_80g_prefix else org.receipt_prefix end;
    final_receipt_number:=prefix||'/'||org.financial_year||'/'||lpad(seq::text,5,'0');
    while exists(select 1 from public.receipts where organization_id=d.organization_id and receipt_number=final_receipt_number) loop
      seq:=seq+1;
      update public.receipt_counters set current_number=seq
      where organization_id=d.organization_id and financial_year=org.financial_year and receipt_type=rt;
      final_receipt_number:=prefix||'/'||org.financial_year||'/'||lpad(seq::text,5,'0');
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
  collector_org uuid;
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
      payment_date=coalesce(p_payment_date,current_date),
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


-- V1.7.2 final function overrides
-- RYM_VARGANI V1.7.2
-- Receipt numbering floor 250 + duplicate-safe auto numbering + invalidate Drive PDF after edits.

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
  prefix text;
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
    values(d.organization_id,org.financial_year,rt,250)
    on conflict(organization_id,financial_year,receipt_type)
    do update set current_number=greatest(public.receipt_counters.current_number+1,250)
    returning current_number into seq;
    prefix:=case when rt='80g' then org.receipt_80g_prefix else org.receipt_prefix end;
    final_receipt_number:=prefix||'/'||org.financial_year||'/'||lpad(seq::text,5,'0');
    while exists(select 1 from public.receipts where organization_id=d.organization_id and receipt_number=final_receipt_number) loop
      seq:=seq+1;
      update public.receipt_counters set current_number=seq
      where organization_id=d.organization_id and financial_year=org.financial_year and receipt_type=rt;
      final_receipt_number:=prefix||'/'||org.financial_year||'/'||lpad(seq::text,5,'0');
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
      receipt_type=new_receipt_type,
      google_drive_file_id=null,
      google_drive_url=null,
      google_drive_uploaded_at=null
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


-- V1.7.2.8 final receipt-edit override
-- RYM_VARGANI V1.7.2.8
-- When a receipt is edited from a paid mode to Receipt Given - Payment Pending,
-- clear payment_received_date so Day-wise paid collection no longer includes it.

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
      payment_received_date=case
        when new_status='receipt_pending' then null
        when coalesce(pay.payment_status,'paid')='receipt_pending' and new_status='paid'
          then coalesce(pay.payment_received_date,p_payment_date,current_date)
        else coalesce(pay.payment_received_date,p_payment_date,current_date)
      end,
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
      receipt_type=new_receipt_type,
      google_drive_file_id=null,
      google_drive_url=null,
      google_drive_uploaded_at=null
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


-- V1.7.3.0 final plain-numeric receipt numbering override
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


-- V1.7.3.4 Super Admin delete role mapping fix
-- RYM_VARGANI V1.7.3.4
-- Fix Super Admin receipt deletion role mapping.
-- In the app, database role "owner" is displayed as "Super Admin".
-- The previous delete function checked only Super Admin text variants.

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
  select * into rec
  from public.receipts
  where id=p_receipt_id;

  if rec.id is null then
    raise exception 'Receipt not found';
  end if;

  select role::text into member_role
  from public.organization_members
  where organization_id=rec.organization_id
    and user_id=auth.uid()
    and active=true
  limit 1;

  -- DB role "owner" = App role "Super Admin".
  if coalesce(lower(trim(member_role)),'') not in
     ('owner','super admin','super_admin','superadmin') then
    raise exception 'Only Super Admin can delete receipts';
  end if;

  delete from public.receipts
  where id=rec.id;

  delete from public.payments
  where id=rec.payment_id;
end
$$;

grant execute on function public.super_admin_delete_receipt(uuid) to authenticated;


-- V1.7.3.5 payment mode fix
-- RYM_VARGANI V1.7.3.5
-- Fix Edit Receipt payment mode display and save behavior.

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
      payment_received_date=case
        when new_status='receipt_pending' then null
        when coalesce(pay.payment_status,'paid')='receipt_pending' and new_status='paid'
          then coalesce(pay.payment_received_date,p_payment_date,current_date)
        else coalesce(pay.payment_received_date,p_payment_date,current_date)
      end,
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
      payment_mode_snapshot=case
        when new_status='receipt_pending' then 'Receipt Given - Payment Pending'
        when db_mode='upi' then 'UPI'
        when db_mode='cash' then 'Cash'
        when db_mode='bank' then 'Bank'
        when db_mode='cheque' then 'Cheque'
        else initcap(db_mode::text)
      end,
      cheque_number_snapshot=case when db_mode='cheque' and new_status='paid' then nullif(trim(p_cheque_no),'') else null end,
      bank_name_snapshot=case when new_status='paid' then nullif(trim(p_bank_name),'') else null end,
      receipt_type=new_receipt_type,
      google_drive_file_id=null,
      google_drive_url=null,
      google_drive_uploaded_at=null
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

update public.receipts
set payment_mode_snapshot='UPI'
where lower(coalesce(payment_mode_snapshot,''))='upi';

-- Retain corrected Super Admin deletion permissions
-- RYM_VARGANI V1.7.3.4
-- Fix Super Admin receipt deletion role mapping.
-- In the app, database role "owner" is displayed as "Super Admin".
-- The previous delete function checked only Super Admin text variants.

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
  select * into rec
  from public.receipts
  where id=p_receipt_id;

  if rec.id is null then
    raise exception 'Receipt not found';
  end if;

  select role::text into member_role
  from public.organization_members
  where organization_id=rec.organization_id
    and user_id=auth.uid()
    and active=true
  limit 1;

  -- DB role "owner" = App role "Super Admin".
  if coalesce(lower(trim(member_role)),'') not in
     ('owner','super admin','super_admin','superadmin') then
    raise exception 'Only Super Admin can delete receipts';
  end if;

  delete from public.receipts
  where id=rec.id;

  delete from public.payments
  where id=rec.payment_id;
end
$$;

grant execute on function public.super_admin_delete_receipt(uuid) to authenticated;



-- RYM_VARGANI V1.7.4.0
-- Allows an authenticated organization member to confirm the donor's
-- current-year expected/final donation amount during collection.

create or replace function public.set_donor_current_expected(
  p_donor_id uuid,
  p_expected_amount numeric
)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_org_id uuid;
begin
  if p_expected_amount < 0 then
    raise exception 'Expected amount cannot be negative';
  end if;

  select organization_id into v_org_id
  from public.donors
  where id=p_donor_id;

  if v_org_id is null then
    raise exception 'Donor not found';
  end if;

  if not exists (
    select 1
    from public.organization_members
    where organization_id=v_org_id
      and user_id=auth.uid()
      and active=true
  ) then
    raise exception 'You are not authorized for this organization';
  end if;

  update public.donors
  set current_expected_amount=p_expected_amount,
      updated_at=now()
  where id=p_donor_id;
end
$$;

grant execute on function public.set_donor_current_expected(uuid,numeric) to authenticated;


-- RYM_VARGANI V1.7.4.1
-- Treasurer, Admin and Super Admin/Owner may soft-remove an individual donor.

create or replace function public.admin_remove_donor(p_donor_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  d_org uuid;
  member_role text;
begin
  select organization_id into d_org
  from public.donors
  where id=p_donor_id and active=true;

  if d_org is null then
    raise exception 'Donor not found';
  end if;

  select role::text into member_role
  from public.organization_members
  where organization_id=d_org
    and user_id=auth.uid()
    and active=true
  limit 1;

  if coalesce(lower(trim(member_role)),'') not in
     ('owner','super admin','super_admin','superadmin','admin','treasurer') then
    raise exception 'Only Treasurer, Admin or Super Admin can delete a donor';
  end if;

  update public.donors
  set active=false,
      updated_at=now()
  where id=p_donor_id;
end
$$;

grant execute on function public.admin_remove_donor(uuid) to authenticated;
