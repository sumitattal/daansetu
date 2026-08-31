-- RYM_VARGANI V1.7.5.1 - Expense reimbursement + annual membership fees
alter table public.organization_people add column if not exists annual_fee numeric(12,2) not null default 0;

alter table public.expenses add column if not exists payer_type text not null default 'mandal';
alter table public.expenses add column if not exists member_id uuid references public.organization_people(id) on delete set null;
alter table public.expenses add column if not exists member_name text;
alter table public.expenses add column if not exists reimbursement_status text not null default 'not_applicable';
alter table public.expenses add column if not exists reimbursement_date date;
alter table public.expenses add column if not exists returned_by uuid;
alter table public.expenses add column if not exists returned_by_name text;
alter table public.expenses add column if not exists updated_by uuid;
alter table public.expenses add column if not exists updated_by_name text;
alter table public.expenses add column if not exists updated_at timestamptz;

do $$ begin
 alter table public.expenses add constraint expenses_payer_type_check check(payer_type in ('mandal','member'));
exception when duplicate_object then null; end $$;
do $$ begin
 alter table public.expenses add constraint expenses_reimbursement_status_check check(reimbursement_status in ('not_applicable','pending','returned'));
exception when duplicate_object then null; end $$;

create table if not exists public.member_annual_fee_payments(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 member_id uuid not null references public.organization_people(id) on delete cascade,
 amount numeric(12,2) not null check(amount>0),
 payment_date date not null default current_date,
 payment_mode text not null check(payment_mode in ('Cash','UPI','Bank','Cheque')),
 cheque_number text,
 bank_name text,
 payment_status text not null default 'paid' check(payment_status in ('paid','cancelled')),
 collected_by uuid default auth.uid(),
 created_at timestamptz not null default now()
);
alter table public.member_annual_fee_payments enable row level security;

drop policy if exists "member fee authorized read" on public.member_annual_fee_payments;
create policy "member fee authorized read" on public.member_annual_fee_payments for select to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=member_annual_fee_payments.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
drop policy if exists "member fee authorized insert" on public.member_annual_fee_payments;
create policy "member fee authorized insert" on public.member_annual_fee_payments for insert to authenticated with check (
 exists(select 1 from public.organization_members m where m.organization_id=member_annual_fee_payments.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
grant select,insert on public.member_annual_fee_payments to authenticated;

-- Treasurer/Admin/Super Admin may delete expense records.
drop policy if exists "expense authorized delete" on public.expenses;
create policy "expense authorized delete" on public.expenses for delete to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=expenses.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
grant delete on public.expenses to authenticated;
