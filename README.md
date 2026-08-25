# RYM_VARGANI V1.5.8

Mobile/PWA donation management release for Rajasthan Yuvak Mandal and reusable organizations.

## New in V1.5.8

- First-time setup link removed from the public login page.
- New collection mode: **Receipt Given - Payment Pending**.
- New **Payment Pending** tab. A user can later mark a pending receipt as paid and select Cash / UPI / Bank / Cheque.
- Collection Date field added to the collection form.
- Donor Collection Report now includes Date and can be downloaded to Excel.
- New **Day-wise Report** with date picker showing Cash, UPI, Cheque and Receipt-Issued/Payment-Pending totals.
- Dashboard now includes a date-wise paid collection graph.
- Optional donor **Reference** field added to Add Donor and donor bulk upload.
- Receipt preview alignment/font refined against the supplied receipt PDF.
- Receipt screen includes a **WhatsApp** share action. On supported Android/iOS browsers it shares a generated receipt PNG through the native share sheet; select WhatsApp and the donor/contact. If file sharing is unavailable it opens the donor's WhatsApp chat with a message.
- Existing mobile/PWA behavior retained.

## IMPORTANT - existing Supabase database

Run this file once in Supabase SQL Editor before using V1.5.8:

`supabase/upgrade-v1.5.8.sql`

Expected result: `Success. No rows returned`.

The upgrade preserves existing donors, users, routes, payments and receipts.

## Run locally

Copy your existing `.env.local` into this project folder, then:

```bash
npm install
npm run build
npm run dev
```

## Deploy existing Vercel app

Push the updated source to the same GitHub repository. Vercel will automatically create a new deployment from the `main` branch. No new Vercel environment variables are required.

## Payment Pending behavior

A receipt-pending entry creates the receipt immediately but **does not count toward Collected** until the payment is changed to Cash / UPI / Bank / Cheque in the Payment Pending tab.

## WhatsApp note

Web browsers do not allow a website to silently attach a file to a preselected WhatsApp recipient. On phones that support Web Share, RYM_VARGANI generates the receipt as a PNG and opens the native share sheet with the file attached; choose WhatsApp and the intended contact. The fallback opens the donor's WhatsApp chat with a prepared message.


## V1.5.9 — Editable Receipts + Audit Log
- Any active RYM_VARGANI user can edit an existing receipt from Receipt Centre / 80G Receipts.
- Editable values: receipt number, donor name, mobile, PAN, date, amount, payment mode/status, cheque/bank details, area snapshot and Normal/80G type.
- Every actual change creates an immutable `receipt_audit_log` row with editor, timestamp, before/after values and changed fields.
- Admin/Super Admin can review the audit history in Admin Panel.
- Audit information is never printed on the donor receipt.
- Run `supabase/upgrade-v1.5.9.sql` once on an existing V1.5.8 database.


## V1.6.0 mobile route collection update
- Mobile Route Collection cards now show only donor name/mobile, route, last-year donation and Collect.
- Collect amount is pre-filled from last-year donation and remains editable.
- Collect action uses Save & Send and immediately opens the mobile receipt-sharing flow after saving.
- No database migration is required from V1.5.9.
