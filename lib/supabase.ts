import { createClient } from '@supabase/supabase-js'

export function getSupabaseBrowserClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
  if (!url || !key) return null
  return createClient(url, key)
}

export function loginNameToEmail(loginName: string) {
  return `${loginName.trim().toLowerCase().replace(/[^a-z0-9._-]/g, '')}@users.daansetu.app`
}
