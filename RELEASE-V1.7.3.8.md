# RYM_VARGANI V1.7.3.8

## Pending Donors Excel dropdown
In Reports, Super Admin, Admin and Treasurer now get a route selector.

### All Routes
Downloads one Excel workbook with separate route-wise tabs.
Each tab contains:
- SrNo
- Donor Name
- Mobile Number
- Last Year Donation

Only donors with pending balance are included.

### Particular Route
Downloads one Excel file for that selected route only.
It contains:
- SrNo
- Donor Name
- Mobile Number
- Last Year Donation
- Expected Amount
- Collected Amount
- Pending Amount

No Supabase SQL change is required.
All previous fixes are retained.
