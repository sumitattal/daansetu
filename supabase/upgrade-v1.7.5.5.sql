-- RYM_VARGANI V1.7.5.5 - Member Edit/Delete permissions
-- Treasurer, Admin and Super Admin/owner can update/delete members in their organization.

drop policy if exists "member management update" on public.organization_people;
create policy "member management update" on public.organization_people
for update to authenticated
using (
 exists(select 1 from public.organization_members m
  where m.organization_id=organization_people.organization_id
    and m.user_id=auth.uid() and m.active=true
    and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
)
with check (
 exists(select 1 from public.organization_members m
  where m.organization_id=organization_people.organization_id
    and m.user_id=auth.uid() and m.active=true
    and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);

drop policy if exists "member management delete" on public.organization_people;
create policy "member management delete" on public.organization_people
for delete to authenticated
using (
 exists(select 1 from public.organization_members m
  where m.organization_id=organization_people.organization_id
    and m.user_id=auth.uid() and m.active=true
    and lower(m.role::text) in ('owner','super admin','super_admin','superadmin','admin','treasurer'))
);

grant update,delete on public.organization_people to authenticated;
