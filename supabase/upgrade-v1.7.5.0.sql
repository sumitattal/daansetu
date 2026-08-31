-- RYM_VARGANI V1.7.5.0 - Expense & Quotation Management
create table if not exists public.expenses (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 expense_type text not null check (expense_type in ('with_bill','without_bill')),
 expense_head text not null,
 bill_name text,
 invoice_number text,
 vendor_name text,
 expense_date date not null default current_date,
 amount numeric(12,2) not null check(amount > 0),
 gst_amount numeric(12,2) not null default 0,
 description text,
 payment_status text not null default 'pending' check(payment_status in ('pending','paid')),
 payment_mode text check(payment_mode is null or payment_mode in ('Cash','Cheque')),
 payment_date date,
 cheque_number text,
 bank_name text,
 cheque_date date,
 attachment_url text,
 created_by uuid,
 created_by_name text,
 created_at timestamptz not null default now(),
 paid_by uuid,
 paid_by_name text,
 paid_at timestamptz
);
create table if not exists public.quotations (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 vendor_name text not null,
 quotation_for text not null,
 expense_head text,
 amount numeric(12,2) not null default 0,
 quotation_date date not null default current_date,
 validity_date date,
 contact_person text,
 mobile text,
 remarks text,
 status text not null default 'under_review' check(status in ('under_review','approved','rejected')),
 attachment_url text,
 created_by uuid,
 created_by_name text,
 created_at timestamptz not null default now()
);
alter table public.expenses enable row level security;
alter table public.quotations enable row level security;

drop policy if exists "expense authorized read" on public.expenses;
create policy "expense authorized read" on public.expenses for select to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=expenses.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
drop policy if exists "expense authorized insert" on public.expenses;
create policy "expense authorized insert" on public.expenses for insert to authenticated with check (
 exists(select 1 from public.organization_members m where m.organization_id=expenses.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
drop policy if exists "expense authorized update" on public.expenses;
create policy "expense authorized update" on public.expenses for update to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=expenses.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
) with check (
 exists(select 1 from public.organization_members m where m.organization_id=expenses.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
drop policy if exists "quotation authorized read" on public.quotations;
create policy "quotation authorized read" on public.quotations for select to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=quotations.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
drop policy if exists "quotation authorized insert" on public.quotations;
create policy "quotation authorized insert" on public.quotations for insert to authenticated with check (
 exists(select 1 from public.organization_members m where m.organization_id=quotations.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);
drop policy if exists "quotation authorized update" on public.quotations;
create policy "quotation authorized update" on public.quotations for update to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=quotations.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
) with check (
 exists(select 1 from public.organization_members m where m.organization_id=quotations.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('expense-documents','expense-documents',true,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set public=true,file_size_limit=10485760;

drop policy if exists "expense docs authenticated upload" on storage.objects;
create policy "expense docs authenticated upload" on storage.objects for insert to authenticated with check (bucket_id='expense-documents');
drop policy if exists "expense docs public read" on storage.objects;
create policy "expense docs public read" on storage.objects for select using (bucket_id='expense-documents');

grant select,insert,update on public.expenses to authenticated;
grant select,insert,update on public.quotations to authenticated;
