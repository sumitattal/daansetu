import { NextResponse } from 'next/server'
import { exchangeCodeForTokens, verifyGoogleState, googleConfig } from '@/lib/google-drive'
import { getSupabaseAdminClient } from '@/lib/supabase-server'

export async function GET(req: Request) {
  const url = new URL(req.url)
  const appOrigin = googleConfig().redirectUri.replace(/\/api\/google\/callback\/?$/, '')
  try {
    const code = url.searchParams.get('code') || ''
    const state = url.searchParams.get('state') || ''
    const oauthError = url.searchParams.get('error')
    if (oauthError) throw new Error(`Google authorization failed: ${oauthError}`)
    if (!code) throw new Error('Google authorization code is missing.')
    const parsed = verifyGoogleState(state)
    const tokens = await exchangeCodeForTokens(code)
    const supabase = getSupabaseAdminClient()

    const { data: existing } = await supabase
      .from('integration_secrets')
      .select('refresh_token')
      .eq('organization_id', parsed.organizationId)
      .eq('provider', 'google_drive')
      .maybeSingle()

    const refreshToken = tokens.refresh_token || existing?.refresh_token
    if (!refreshToken) throw new Error('Google did not return a refresh token. Reconnect and approve access again.')

    const { error } = await supabase.from('integration_secrets').upsert({
      organization_id: parsed.organizationId,
      provider: 'google_drive',
      refresh_token: refreshToken,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'organization_id,provider' })
    if (error) throw error

    return NextResponse.redirect(`${appOrigin}/?google_drive=connected`)
  } catch (e:any) {
    return NextResponse.redirect(`${appOrigin}/?google_drive=error&message=${encodeURIComponent(e?.message || 'Google Drive connection failed.')}`)
  }
}
