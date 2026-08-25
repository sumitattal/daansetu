import { NextResponse } from 'next/server'
import { getSupabaseAdminClient } from '@/lib/supabase-server'
import { loginNameToEmail } from '@/lib/supabase'

const roleMap: Record<string,string> = { 'Super Admin':'owner', 'Admin':'admin', 'Treasurer':'treasurer', 'Volunteer':'volunteer', 'Viewer':'viewer' }

async function callerProfile(req: Request) {
  const auth = req.headers.get('authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  const supabase = getSupabaseAdminClient()
  const { data: userData, error: userErr } = await supabase.auth.getUser(token)
  if (userErr || !userData.user) return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }) }
  const { data: profile } = await supabase.from('organization_members').select('*').eq('user_id', userData.user.id).in('role',['owner','admin']).eq('active',true).single()
  if (!profile) return { error: NextResponse.json({ error: 'Admin access required.' }, { status: 403 }) }
  return { supabase, profile, callerId: userData.user.id }
}

export async function POST(req: Request) {
  try {
    const c = await callerProfile(req); if ('error' in c) return c.error
    const { supabase, profile } = c
    const body = await req.json()
    const loginName = String(body.loginName || '').trim().toLowerCase()
    const password = String(body.password || '')
    const displayName = String(body.displayName || '').trim()
    const mobile = String(body.mobile || '').trim()
    const role = roleMap[String(body.role || 'Volunteer')] || 'volunteer'
    if (!loginName || !displayName || password.length < 6) return NextResponse.json({ error: 'Login, display name and password (min 6 chars) are required.' }, { status: 400 })
    if (profile.role !== 'owner' && ['owner','admin'].includes(role)) return NextResponse.json({ error: 'Only Super Admin can create an Admin or Super Admin.' }, { status: 403 })
    const { data: created, error: createError } = await supabase.auth.admin.createUser({ email: loginNameToEmail(loginName), password, email_confirm: true })
    if (createError || !created.user) throw createError || new Error('Could not create user')
    const { error: profileError } = await supabase.from('organization_members').insert({ organization_id: profile.organization_id, user_id: created.user.id, role, display_name: displayName, mobile: mobile || null, login_name: loginName, active: true })
    if (profileError) { await supabase.auth.admin.deleteUser(created.user.id); throw profileError }
    return NextResponse.json({ ok: true })
  } catch (e:any) {
    return NextResponse.json({ error: e?.message || 'User creation failed.' }, { status: 500 })
  }
}

export async function PATCH(req: Request) {
  try {
    const c = await callerProfile(req); if ('error' in c) return c.error
    const { supabase, profile } = c
    if (profile.role !== 'owner') return NextResponse.json({ error: 'Only Super Admin can edit users.' }, { status: 403 })

    const body = await req.json()
    const userId = String(body.userId || '')
    const displayName = String(body.displayName || '').trim()
    const mobile = String(body.mobile || '').trim()
    const role = roleMap[String(body.role || '')]
    const active = body.active !== false
    const password = String(body.password || '')
    if (!userId || !displayName || !role) return NextResponse.json({ error: 'User, display name and role are required.' }, { status: 400 })
    if (password && password.length < 6) return NextResponse.json({ error: 'New password must be at least 6 characters.' }, { status: 400 })

    const { data: target } = await supabase.from('organization_members').select('*').eq('organization_id', profile.organization_id).eq('user_id', userId).single()
    if (!target) return NextResponse.json({ error: 'User not found in this organization.' }, { status: 404 })

    // Never allow the organization to lose its last active Super Admin.
    if (target.role === 'owner' && target.active && (role !== 'owner' || !active)) {
      const { count } = await supabase.from('organization_members').select('*',{count:'exact',head:true}).eq('organization_id',profile.organization_id).eq('role','owner').eq('active',true)
      if ((count || 0) <= 1) return NextResponse.json({ error: 'The last active Super Admin cannot be demoted or deactivated.' }, { status: 400 })
    }

    const { error: updateError } = await supabase.from('organization_members').update({ display_name: displayName, mobile: mobile || null, role, active }).eq('organization_id', profile.organization_id).eq('user_id', userId)
    if (updateError) throw updateError
    if (password) {
      const { error: pwError } = await supabase.auth.admin.updateUserById(userId,{ password })
      if (pwError) throw pwError
    }
    return NextResponse.json({ ok: true })
  } catch (e:any) {
    return NextResponse.json({ error: e?.message || 'User update failed.' }, { status: 500 })
  }
}
