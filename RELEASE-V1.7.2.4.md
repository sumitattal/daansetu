# RYM_VARGANI V1.7.2.4 — Mobile Edit + Current WhatsApp Number + Partial Search

- **Edit Donor** is now explicitly visible in the mobile Donors view for Admin/Super Admin.
- Desktop Donors view also has a dedicated Edit Donor action.
- Editing donor details does **not** update payment/receipt status.
- WhatsApp receipt sending now resolves the donor's **current mobile number from the Donors table at send time**.
  - If a donor mobile number is edited after a receipt was generated, Send Receipt and WhatsApp Reminder use the new number.
  - Historical receipt snapshots remain unchanged.
- Donor searches now use partial/token matching.
  - Example: `Maniyar Sagar Kedarnath` matches `saga`, `sagar`, `kedar`, `kedarnath`, `maniy`, etc.
- Partial matching is applied to Dashboard donor search, Donors/Route/Pending search and Receipt search.
- No new Supabase migration required beyond `upgrade-v1.7.2.sql`.
