# RYM_VARGANI V1.7.0 — Google Drive Receipt Upload + WhatsApp Link

## Added
- Admin Panel → Connect Google Drive.
- Google OAuth 2.0 using the `drive.file` scope.
- Server-only refresh-token storage in Supabase `integration_secrets`.
- Receipt PDF generation using the same calibrated receipt renderer.
- Automatic receipt PDF upload to `GOOGLE_DRIVE_FOLDER_ID`.
- Per-file `anyone / reader` permission; the whole Drive folder stays private.
- Google Drive file ID / URL / uploaded time saved on each receipt.
- Receipt → WhatsApp uploads the PDF if needed, then opens the exact donor chat with the Drive receipt link.
- New receipts are uploaded in the background; Save & Send waits for the link before opening WhatsApp.

## Required
Run `supabase/upgrade-v1.7.0.sql` once.

Environment variables:
- GOOGLE_CLIENT_ID
- GOOGLE_CLIENT_SECRET
- GOOGLE_DRIVE_FOLDER_ID
- GOOGLE_REDIRECT_URI
- optional GOOGLE_OAUTH_STATE_SECRET

For production, GOOGLE_REDIRECT_URI must be:
`https://daansetu.maxtechsangamner.in/api/google/callback`
