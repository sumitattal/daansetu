# RYM_VARGANI V1.7.2

- Route Collection hides donors whose status is **Receipt Given - Payment Pending**.
- Auto-generated receipt numbering starts at **250** and skips numbers that already exist.
- Manual receipt numbers are checked for duplicates in the app and Supabase.
- Dashboard includes donor-name search; results show donor name and payment status.
- Dashboard donor actions:
  - Pending → Collect
  - Receipt Given - Payment Pending → Mark Payment + WhatsApp Reminder
  - Collected → Send Receipt
- WhatsApp Reminder includes receipt number, amount and the supplied Payment QR link.
- The supplied QR is included as `public/rym-payment-qr.jpeg`.
- Mark Payment uses a Payment Mode dropdown (Cash / UPI / Bank / Cheque), Payment Received Date, and cheque details when applicable.
- Editing a receipt invalidates the old Google Drive link and attempts to delete the old PDF; the next send generates/uploads the corrected receipt.
- Day-wise Collection Report includes Payment Mode filtering.
- Run `supabase/upgrade-v1.7.2.sql` before using the new receipt-numbering/edit behavior.
