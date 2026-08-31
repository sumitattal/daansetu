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
