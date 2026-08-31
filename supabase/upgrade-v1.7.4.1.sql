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
