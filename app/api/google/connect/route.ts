import { NextResponse } from 'next/server'
import { createGoogleState, getOrgCaller, googleConfig } from '@/lib/google-drive'

export async function POST(req: Request) {
  try {
    const caller = await getOrgCaller(req)
    if (!['owner','admin'].includes(caller.role)) return NextResponse.json({ error: 'Admin access required.' }, { status: 403 })
    const { clientId, redirectUri } = googleConfig()
    const state = createGoogleState(caller.organizationId)
    const q = new URLSearchParams({
      client_id: clientId,
      redirect_uri: redirectUri,
      response_type: 'code',
      access_type: 'offline',
      prompt: 'consent',
      scope: 'https://www.googleapis.com/auth/drive.file',
      state,
    })
    return NextResponse.json({ url: `https://accounts.google.com/o/oauth2/v2/auth?${q.toString()}` })
  } catch (e:any) {
    return NextResponse.json({ error: e?.message || 'Could not start Google Drive connection.' }, { status: 500 })
  }
}
