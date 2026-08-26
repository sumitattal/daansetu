import crypto from 'crypto'
import { getSupabaseAdminClient } from '@/lib/supabase-server'

export type OrgCaller = {
  userId: string
  organizationId: string
  role: string
}

export async function getOrgCaller(req: Request): Promise<OrgCaller> {
  const auth = req.headers.get('authorization') || ''
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : ''
  if (!token) throw new Error('Unauthorized')
  const supabase = getSupabaseAdminClient()
  const { data: userData, error: userErr } = await supabase.auth.getUser(token)
  if (userErr || !userData.user) throw new Error('Unauthorized')
  const { data: profile, error: profileErr } = await supabase
    .from('organization_members')
    .select('organization_id,role,active')
    .eq('user_id', userData.user.id)
    .eq('active', true)
    .single()
  if (profileErr || !profile) throw new Error('Active organization membership required.')
  return { userId: userData.user.id, organizationId: profile.organization_id, role: profile.role }
}

function stateSecret() {
  const secret = process.env.GOOGLE_OAUTH_STATE_SECRET || process.env.DAANSETU_SETUP_TOKEN
  if (!secret) throw new Error('GOOGLE_OAUTH_STATE_SECRET or DAANSETU_SETUP_TOKEN is required.')
  return secret
}

export function createGoogleState(organizationId: string) {
  const payload = Buffer.from(JSON.stringify({ organizationId, ts: Date.now() })).toString('base64url')
  const sig = crypto.createHmac('sha256', stateSecret()).update(payload).digest('base64url')
  return `${payload}.${sig}`
}

export function verifyGoogleState(state: string) {
  const [payload, sig] = String(state || '').split('.')
  if (!payload || !sig) throw new Error('Invalid OAuth state.')
  const expected = crypto.createHmac('sha256', stateSecret()).update(payload).digest('base64url')
  const a = Buffer.from(sig)
  const b = Buffer.from(expected)
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) throw new Error('Invalid OAuth state.')
  const parsed = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'))
  if (!parsed.organizationId || !parsed.ts || Date.now() - Number(parsed.ts) > 15 * 60 * 1000) throw new Error('Expired OAuth state.')
  return parsed as { organizationId: string; ts: number }
}

export function googleConfig() {
  const clientId = process.env.GOOGLE_CLIENT_ID
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET
  const redirectUri = process.env.GOOGLE_REDIRECT_URI
  const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID
  if (!clientId || !clientSecret || !redirectUri || !folderId) throw new Error('Google Drive environment variables are incomplete.')
  return { clientId, clientSecret, redirectUri, folderId }
}

export async function exchangeCodeForTokens(code: string) {
  const { clientId, clientSecret, redirectUri } = googleConfig()
  const body = new URLSearchParams({
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri,
    grant_type: 'authorization_code',
  })
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
    cache: 'no-store',
  })
  const j = await r.json()
  if (!r.ok) throw new Error(j.error_description || j.error || 'Google OAuth token exchange failed.')
  return j as { access_token: string; refresh_token?: string; expires_in?: number; scope?: string; token_type?: string }
}

export async function refreshGoogleAccessToken(refreshToken: string) {
  const { clientId, clientSecret } = googleConfig()
  const body = new URLSearchParams({
    refresh_token: refreshToken,
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: 'refresh_token',
  })
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
    cache: 'no-store',
  })
  const j = await r.json()
  if (!r.ok || !j.access_token) throw new Error(j.error_description || j.error || 'Could not refresh Google access token.')
  return String(j.access_token)
}

export async function getDriveRefreshToken(organizationId: string) {
  const supabase = getSupabaseAdminClient()
  const { data, error } = await supabase
    .from('integration_secrets')
    .select('refresh_token')
    .eq('organization_id', organizationId)
    .eq('provider', 'google_drive')
    .maybeSingle()
  if (error) throw error
  if (!data?.refresh_token) throw new Error('Google Drive is not connected. Ask an Admin to connect it from Admin Panel.')
  return String(data.refresh_token)
}

export async function uploadPdfToGoogleDrive(accessToken: string, pdf: ArrayBuffer, filename: string) {
  const { folderId } = googleConfig()

  const create = await fetch('https://www.googleapis.com/drive/v3/files?fields=id,name,webViewLink', {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ name: filename, mimeType: 'application/pdf', parents: [folderId] }),
    cache: 'no-store',
  })
  const created = await create.json()
  if (!create.ok || !created.id) throw new Error(created?.error?.message || 'Could not create Google Drive receipt file.')

  const fileId = String(created.id)
  const upload = await fetch(`https://www.googleapis.com/upload/drive/v3/files/${encodeURIComponent(fileId)}?uploadType=media`, {
    method: 'PATCH',
    headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/pdf' },
    body: Buffer.from(pdf),
    cache: 'no-store',
  })
  if (!upload.ok) {
    const e = await upload.json().catch(() => ({}))
    throw new Error(e?.error?.message || 'Could not upload receipt PDF to Google Drive.')
  }

  const permission = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileId)}/permissions`, {
    method: 'POST',
    headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
    body: JSON.stringify({ role: 'reader', type: 'anyone' }),
    cache: 'no-store',
  })
  if (!permission.ok) {
    const e = await permission.json().catch(() => ({}))
    throw new Error(e?.error?.message || 'Could not create receipt sharing permission.')
  }

  const info = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(fileId)}?fields=id,name,webViewLink`, {
    headers: { authorization: `Bearer ${accessToken}` },
    cache: 'no-store',
  })
  const file = await info.json()
  if (!info.ok) throw new Error(file?.error?.message || 'Could not read Google Drive receipt link.')
  return { fileId, url: file.webViewLink || `https://drive.google.com/file/d/${fileId}/view` }
}
