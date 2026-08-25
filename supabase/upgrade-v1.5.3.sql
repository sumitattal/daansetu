-- DaanSetu V1.5.3 upgrade for an existing V1.5.x Supabase database.
-- PAN already exists in V1.5; this migration safely adds donor updated_at,
-- which is used by route-change and admin soft-delete functions.

alter table public.donors
  add column if not exists updated_at timestamptz not null default now();

-- No database migration is required for Super Admin user editing because
-- that action is performed by the secure server-side Admin API.
