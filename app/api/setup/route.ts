import { NextResponse } from 'next/server'
import { getSupabaseAdminClient } from '@/lib/supabase-server'
import { loginNameToEmail } from '@/lib/supabase'

export async function POST(req: Request) {
  try {
    const body = await req.json()
    if (!process.env.DAANSETU_SETUP_TOKEN || body.setupToken !== process.env.DAANSETU_SETUP_TOKEN) {
      return NextResponse.json({ error: 'Invalid setup token.' }, { status: 401 })
    }
    const loginName = String(body.loginName || '').trim().toLowerCase()
    const password = String(body.password || '')
    const displayName = String(body.displayName || '').trim()
    const organizationName = String(body.organizationName || 'Rajasthan Yuvak Mandal').trim()
    if (!loginName || password.length < 6 || !displayName) return NextResponse.json({ error: 'Login, display name and password (min 6 chars) are required.' }, { status: 400 })
    const supabase = getSupabaseAdminClient()
    const existing = await supabase.from('organizations').select('id').limit(1)
    if ((existing.data?.length || 0) > 0) return NextResponse.json({ error: 'Setup is already complete.' }, { status: 409 })

    const { data: authData, error: authError } = await supabase.auth.admin.createUser({ email: loginNameToEmail(loginName), password, email_confirm: true })
    if (authError || !authData.user) throw authError || new Error('Could not create admin user')
    const { data: org, error: orgError } = await supabase.from('organizations').insert({ name: organizationName, name_mr: 'राजस्थान युवक मंडळ', receipt_prefix: 'RYM', receipt_80g_prefix: 'RYM/80G', financial_year: '2026-27' }).select().single()
    if (orgError) throw orgError
    const { error: memberError } = await supabase.from('organization_members').insert({ organization_id: org.id, user_id: authData.user.id, role: 'owner', display_name: displayName, login_name: loginName, active: true })
    if (memberError) throw memberError
    await supabase.from('routes').insert(['Ashok Chowk','Main Road','Market Yard','Delhi Naka','Akole Naka'].map(name => ({ organization_id: org.id, name })))
    return NextResponse.json({ ok: true })
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || 'Setup failed.' }, { status: 500 })
  }
}
