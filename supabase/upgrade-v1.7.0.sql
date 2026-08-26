-- RYM_VARGANI V1.7.0 - Google Drive receipt integration

alter table public.receipts
  add column if not exists google_drive_file_id text,
  add column if not exists google_drive_url text,
  add column if not exists google_drive_uploaded_at timestamptz;

create table if not exists public.integration_secrets (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  provider text not null,
  refresh_token text not null,
  updated_at timestamptz not null default now(),
  primary key (organization_id, provider)
);

alter table public.integration_secrets enable row level security;

-- Intentionally no client-side RLS policies.
-- Only the server-side Supabase service-role client reads/writes integration_secrets.
