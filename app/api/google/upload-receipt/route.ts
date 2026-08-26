import { NextResponse } from 'next/server'
import { getDriveRefreshToken, getOrgCaller, refreshGoogleAccessToken, uploadPdfToGoogleDrive } from '@/lib/google-drive'
import { getSupabaseAdminClient } from '@/lib/supabase-server'

export async function POST(req: Request) {
  try {
    const caller = await getOrgCaller(req)
    const form = await req.formData()
    const receiptId = String(form.get('receiptId') || '')
    const filename = String(form.get('filename') || 'RYM_VARGANI-Receipt.pdf').replace(/[^\w .()_-]/g, '-')
    const file = form.get('file')
    if (!receiptId || !(file instanceof File)) return NextResponse.json({ error: 'Receipt ID and PDF file are required.' }, { status: 400 })
    if (file.type !== 'application/pdf') return NextResponse.json({ error: 'Receipt file must be a PDF.' }, { status: 400 })
    if (file.size > 12 * 1024 * 1024) return NextResponse.json({ error: 'Receipt PDF is too large.' }, { status: 400 })

    const supabase = getSupabaseAdminClient()
    const { data: receipt, error: receiptErr } = await supabase
      .from('receipts')
      .select('id,organization_id,google_drive_file_id,google_drive_url')
      .eq('id', receiptId)
      .eq('organization_id', caller.organizationId)
      .single()
    if (receiptErr || !receipt) return NextResponse.json({ error: 'Receipt not found.' }, { status: 404 })

    if (receipt.google_drive_url) {
      return NextResponse.json({ ok: true, fileId: receipt.google_drive_file_id, url: receipt.google_drive_url, reused: true })
    }

    const refreshToken = await getDriveRefreshToken(caller.organizationId)
    const accessToken = await refreshGoogleAccessToken(refreshToken)
    const uploaded = await uploadPdfToGoogleDrive(accessToken, await file.arrayBuffer(), filename)

    const { error: updateErr } = await supabase.from('receipts').update({
      google_drive_file_id: uploaded.fileId,
      google_drive_url: uploaded.url,
      google_drive_uploaded_at: new Date().toISOString(),
    }).eq('id', receiptId).eq('organization_id', caller.organizationId)
    if (updateErr) throw updateErr

    return NextResponse.json({ ok: true, ...uploaded })
  } catch (e:any) {
    return NextResponse.json({ error: e?.message || 'Google Drive receipt upload failed.' }, { status: 500 })
  }
}
