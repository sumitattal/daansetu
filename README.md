# DaanSetu V1.5 — Live Database

This build replaces demo/local state with a real Supabase database and Supabase Auth.

## Live features
- Separate login name + password for every user (Supabase Auth)
- Super Admin / Admin / Treasurer / Volunteer / Viewer roles
- Admin panel for creating users
- Route master; volunteers choose any route from a dropdown (no route assignment)
- Donors stored permanently in Supabase
- Bulk donor upload: Donor Name is compulsory; Contact Person, Last Year Donation, Last Year Receipt Number and Route are optional
- Members stored permanently in Supabase
- Bulk member upload: Name + Mobile are compulsory; Birth Date is optional
- Collection/payment entries stored permanently
- Atomic receipt numbering in PostgreSQL
- Normal / 80G receipts stored permanently
- Receipt uses the uploaded Rajasthan Yuvak Mandal design; donor name is English-only and `रक्कम स्वीकारणार` comes from the logged-in user
- Receipts and reports are built from live data

## 1. Create Supabase project
Create a project at Supabase. In SQL Editor run the complete file `supabase/schema.sql`.

## 2. Environment file
Copy `.env.example` to `.env.local` and fill:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
DAANSETU_SETUP_TOKEN=choose-a-long-random-private-string
```

Important: `SUPABASE_SERVICE_ROLE_KEY` and `DAANSETU_SETUP_TOKEN` are server-only secrets. Never expose them in client-side code or screenshots.

## 3. Install and run
From the exact folder containing `package.json`:

```bat
npm install
npm run dev
```

Open http://localhost:3000

## 4. First-time setup
On the login screen click **First-time setup**. Enter organization name, Super Admin display name, login name, password and the same `DAANSETU_SETUP_TOKEN` from `.env.local`.

The setup creates the organization, first Super Admin account, and starter routes. After setup, login with the login name/password you selected.

## 5. Create more users
Login as Super Admin/Admin → **Admin Panel → Add User**. Passwords are stored by Supabase Auth, not in DaanSetu tables.

## 6. Production deployment
For Vercel, add all four environment variables in Project Settings → Environment Variables. Keep the service-role key server-only. After first-time setup, you may remove `DAANSETU_SETUP_TOKEN` from production or rotate it.

## Notes
- The current receipt positioning is calibrated to `public/rym-receipt-template.jpeg`.
- Easebuzz/WhatsApp payment-link integration is reserved for a later release.
- Before going live with 80G receipts, have your CA verify the final legal wording and mandatory fields.


## Final permission rules
- Only **Super Admin** and **Admin** can remove a donor. Removal is a soft-delete (`active=false`) so old payments and receipts remain valid.
- Every active logged-in organization user can change a donor's route from the donor/route collection table.
- Route changes use the dedicated `change_donor_route` database RPC; ordinary non-admin users do not receive general donor-update permission.
- The Admin/Super Admin delete action is enforced by the `admin_remove_donor` database RPC as well as the UI.

If upgrading an existing Supabase database, run the latest `supabase/schema.sql` again in the SQL Editor so the new policies and RPC functions are installed.


## V1.5.2 route management
- Admin and Super Admin can add, rename, and remove routes from Admin Panel.
- A route cannot be removed while active donors are still assigned to it; move those donors first.
- Route removal is a soft delete (`active=false`) to preserve historical data.
- All active logged-in users can continue changing a donor's route from the donor list.
- No database upgrade is required if V1.5.1 schema is already installed, because the existing Admin route policy already permits these updates.

## V1.5.3 changes

- Super Admin can edit an existing application user: Full Name, Mobile, Role, Active/Inactive status, and optionally reset the password.
- Only Super Admin can promote/create Admin or Super Admin roles. Admin can still create Treasurer, Volunteer, and Viewer users.
- The last active Super Admin cannot be demoted or deactivated.
- Donor PAN Number is available on individual donor creation and remains optional.
- Bulk Donor Upload supports optional `PAN Number` and `Mobile Number` columns in addition to Donor Name, Contact Person, Route, Last Year Donation, and Last Year Receipt Number.
- Existing V1.5.x databases should run `supabase/upgrade-v1.5.3.sql` once.


## V1.5.4 bulk donor import fix

- Bulk donor import now reuses existing routes instead of attempting duplicate route inserts.
- Route matching trims leading/trailing spaces, collapses repeated spaces, and matches case-insensitively in the application.
- Only missing routes are created.
- Donors are inserted in batches for faster large imports.
- A completion summary reports donor count, existing routes reused, and new routes created.
- No Supabase schema migration is required when upgrading from V1.5.3.

## V1.5.5 donor collection/table update
- Collection popup now has an **Edit Route** button. Any authenticated member can change the selected donor's route while collecting.
- Donor table columns now show: Donor Name, PAN, Route, Last Year Donation, Expected, Collected, Balance, Status.
- Super Admin gets row checkboxes, Select All for the current filtered list, and **Delete Selected** bulk soft-delete.
- Admin/Super Admin keep individual donor delete; bulk delete is Super Admin only.
- No new Supabase migration is required because V1.5.5 uses the existing `change_donor_route` and `admin_remove_donor` RPCs.


## V1.5.6 — Physical Receipt Number + Collection Excel

- Collection popup includes an optional **Receipt Number** field.
- Leave it blank to use the normal DaanSetu system-generated receipt number.
- If a physical receipt was already issued, enter that physical receipt number; it becomes the official receipt number for that payment and replaces the generated number.
- Duplicate receipt numbers are rejected within the organization.
- The route/area at the time of collection is stored as a receipt snapshot.
- Reports now include **Download Collection Excel** with columns: Sr No., DonarName, ContactNumber, PAN, ReceiptNumber, AreaName, ModeofPayment, Amount.
- Existing installations must run `supabase/upgrade-v1.5.6.sql` once in Supabase SQL Editor before using this version.


## V1.5.7 Mobile / PWA update

- Mobile-first donor cards for route collection and donor search.
- Collection modal behaves as a bottom sheet with large touch targets.
- Bottom navigation is horizontally swipeable so every module remains available on mobile.
- iOS-safe 16px form inputs and safe-area support.
- Receipt preview is scrollable on phones while print/PDF remains full resolution.
- PWA manifest and 192/512 icons are included. On Android use Chrome > Install app/Add to Home screen. On iPhone use Safari > Share > Add to Home Screen.
- No database migration is required from V1.5.6.
