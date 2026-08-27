import { NextResponse } from 'next/server'
import { getDriveRefreshToken, getOrgCaller, refreshGoogleAccessToken } from '@/lib/google-drive'

export async function POST(req: Request) {
  try {
    const caller = await getOrgCaller(req)
    const { fileId } = await req.json()
    if (!fileId) return NextResponse.json({ error: 'Google Drive file ID is required.' }, { status: 400 })
    const refreshToken = await getDriveRefreshToken(caller.organizationId)
    const accessToken = await refreshGoogleAccessToken(refreshToken)
    const r = await fetch(`https://www.googleapis.com/drive/v3/files/${encodeURIComponent(String(fileId))}`, {
      method: 'DELETE',
      headers: { authorization: `Bearer ${accessToken}` },
    })
    if (!r.ok && r.status !== 404) throw new Error(`Could not remove old receipt from Google Drive (${r.status}).`)
    return NextResponse.json({ ok: true })
  } catch (e:any) {
    return NextResponse.json({ error: e?.message || 'Could not remove old Google Drive receipt.' }, { status: 500 })
  }
}
