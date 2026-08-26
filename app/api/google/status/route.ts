import { NextResponse } from 'next/server'
import { getOrgCaller } from '@/lib/google-drive'
import { getSupabaseAdminClient } from '@/lib/supabase-server'

export async function GET(req: Request) {
  try {
    const caller = await getOrgCaller(req)
    const supabase = getSupabaseAdminClient()
    const { data, error } = await supabase
      .from('integration_secrets')
      .select('updated_at')
      .eq('organization_id', caller.organizationId)
      .eq('provider', 'google_drive')
      .maybeSingle()
    if (error) throw error
    return NextResponse.json({ connected: !!data, updatedAt: data?.updated_at || null })
  } catch (e:any) {
    return NextResponse.json({ error: e?.message || 'Could not read Google Drive status.' }, { status: 500 })
  }
}
