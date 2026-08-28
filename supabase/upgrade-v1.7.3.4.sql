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
