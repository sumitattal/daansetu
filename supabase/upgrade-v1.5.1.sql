-- DaanSetu V1.5.1 permission upgrade
-- Run this in Supabase SQL Editor if V1.5 schema is already installed.

drop policy if exists "members update donors" on public.donors;
drop policy if exists "admins update donors" on public.donors;
create policy "admins update donors" on public.donors
for update
using (public.is_org_admin(organization_id))
with check (public.is_org_admin(organization_id));

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
  if not public.is_org_admin(d_org) then
    raise exception 'Only Admin or Super Admin can delete a donor';
  end if;

  update public.donors set active=false, updated_at=now() where id=p_donor_id;
end $$;

grant execute on function public.change_donor_route(uuid,uuid) to authenticated;
grant execute on function public.admin_remove_donor(uuid) to authenticated;
