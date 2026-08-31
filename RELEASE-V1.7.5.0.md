# RYM_VARGANI V1.7.5.0

## Expense & Quotation Management
Available only to Treasurer, Admin and Super Admin.

### Expenses
- With Bill / Without Bill
- Expense heads
- Bill/invoice name and number, vendor, date, amount, GST, description
- Bill/supporting image or PDF upload
- Mobile camera capture supported
- New inward bill starts as Payment Pending
- Mark Paid with Cash or Cheque
- Cheque Number, Bank Name and Cheque Date
- Created By / Paid By tracking
- Paid, Pending and Total expense dashboard

### Quotations
- Vendor, quotation purpose/head, amount/date/validity/contact/remarks
- Upload image/PDF or take photo on mobile
- Under Review / Approved / Rejected
- Added By tracking

### Security
- Supabase RLS restricts both modules to Treasurer, Admin and Super Admin (including database owner role).
- GPS is not included.

Run `supabase/upgrade-v1.7.5.0.sql` before using this module.
