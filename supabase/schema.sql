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
