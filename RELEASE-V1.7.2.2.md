# RYM_VARGANI V1.7.2.2 — Dashboard Pending Donors + Last Year Donation

- Dashboard now shows **Pending Donors** count.
- Pending Donors count excludes donors whose status is **Receipt Given - Payment Pending**.
- Total Donors count remains unchanged.
- Dashboard donor search now shows **Last Year Donation** in the selected-donor action row.
- The Last Year Donation block is positioned between donor/status information and the action buttons, matching the marked area in the supplied screenshot.
- No new Supabase migration is required beyond `upgrade-v1.7.2.sql`.
