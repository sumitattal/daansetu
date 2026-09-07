-- RYM_VARGANI V1.7.6.7 - Expense Projects
create table if not exists public.expense_projects (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 description text,
 active boolean not null default true,
 created_by uuid,
 created_by_name text,
 created_at timestamptz not null default now(),
 unique(organization_id,name)
);

alter table public.expenses add column if not exists project_id uuid references public.expense_projects(id) on delete set null;
alter table public.expenses add column if not exists project_name text;

alter table public.expense_projects enable row level security;

drop policy if exists "expense project authorized read" on public.expense_projects;
create policy "expense project authorized read" on public.expense_projects for select to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=expense_projects.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);

drop policy if exists "expense project authorized insert" on public.expense_projects;
create policy "expense project authorized insert" on public.expense_projects for insert to authenticated with check (
 exists(select 1 from public.organization_members m where m.organization_id=expense_projects.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);

drop policy if exists "expense project authorized update" on public.expense_projects;
create policy "expense project authorized update" on public.expense_projects for update to authenticated using (
 exists(select 1 from public.organization_members m where m.organization_id=expense_projects.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
) with check (
 exists(select 1 from public.organization_members m where m.organization_id=expense_projects.organization_id and m.user_id=auth.uid() and m.active=true and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);

grant select,insert,update on public.expense_projects to authenticated;
