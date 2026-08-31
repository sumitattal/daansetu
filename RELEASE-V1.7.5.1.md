# RYM_VARGANI V1.7.5.1

## Expense improvements
- Edit Expense and Delete Expense for Treasurer/Admin/Super Admin.
- Two save choices for Mandal-paid expense: Save (Paid) or Save as Payment Pending.
- Who Paid: Self/Mandal or Member.
- Member selection is fetched from the Members list.
- Member-paid expenses are tracked separately as reimbursement pending.
- Return button records reimbursement; only then is the member-paid amount included in Mandal Expenses.

## Members / Annual Fees
- Member table: SrNo, Member Name, Mobile Number, Birthdate, Annual Fees, Payment Status, Action.
- Treasurer/Admin/Super Admin can Collect annual fees.
- Modes: Cash, UPI, Bank, Cheque.
- Pending members can receive a WhatsApp reminder with the Mandal payment QR link.
- Bulk Member template/import now includes SrNo, Member Name, Mobile Number, Birthdate, Annual Fees.

## Upgrade
Run both `supabase/upgrade-v1.7.5.0.sql` (if not already run) and then `supabase/upgrade-v1.7.5.1.sql`.
GPS is not included.
