# RYM_VARGANI V1.6.0 — Mobile Route Collection + Save & Send

Changes from V1.5.9:

- Mobile **Route Collection** donor cards show only:
  - Donor Name
  - Mobile Number
  - Route
  - Last Year Donation
  - Collect button
- Donors/Pending screens retain the detailed donor cards.
- Clicking **Collect** pre-fills Amount with **Last Year Donation**. The amount remains editable.
- The collection form continues to show the existing route-edit, collection date, manual receipt number, payment mode, PAN, collector, cheque/bank and 80G fields.
- The collection action is now **Save & Send**.
- After a successful database save, RYM_VARGANI opens the mobile receipt sharing flow. On Android/iOS devices supporting Web Share, the generated receipt PNG is offered to the native share sheet (WhatsApp can be selected). If file sharing is unavailable, RYM_VARGANI opens the donor's WhatsApp chat with a pre-filled receipt message and keeps the receipt preview available.
- No Supabase migration is required when upgrading from V1.5.9.

Important browser limitation: a normal PWA cannot silently attach a file to a specific WhatsApp recipient. Fully automatic recipient-targeted media sending requires the WhatsApp Business/Cloud API. RYM_VARGANI uses the safest browser-supported share workflow.
