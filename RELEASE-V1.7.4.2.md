# RYM_VARGANI V1.7.4.2

## Corrected Collection Status Rule

The collection status is now intentionally independent of the Expected Amount once a donor has actually donated this year.

### Status
- This Year Collected = 0 → Pending
- This Year Collected > 0 → Collected
- A donor is **not marked Partial** merely because This Year Collected is below Expected.

This fixes existing database donors automatically because status is recalculated from the current paid collection data when the app loads.

### Donors with Reduced Donation Report
A new expandable report is available under Reports.

A donor appears in this report when:
- This Year Donation > 0
- Last Year Donation > 0
- This Year Donation < Last Year Donation

The report shows Donor, Mobile, Route, Last Year Donation, This Year Donation, and Reduced By, and can be downloaded as Excel by Super Admin/Admin/Treasurer.

Example:
- Last Year ₹15,000, This Year ₹2,500 → Status: Collected; also listed in Reduced Donation Report.
- Last Year ₹0, This Year ₹3,500 → Status: Collected; not listed as Reduced Donation.

### Pending
Once a donor has donated any amount this year, the donor is no longer treated as pending and the difference between Expected and Collected is not counted as Pending.

No new Supabase SQL migration is required for V1.7.4.2.
All V1.7.4.0 and V1.7.4.1 changes are retained.
