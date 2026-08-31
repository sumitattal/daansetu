# RYM_VARGANI V1.7.3.7

## Route-wise Pending Donors Excel
Added a new download option in Reports for **Super Admin, Admin and Treasurer**.

The generated Excel workbook:
- contains only donors with a pending balance;
- has a separate worksheet/tab for each route;
- includes Donor Name, Mobile Number, Expected Amount, Collected Amount and Pending Amount;
- adds a TOTAL pending amount row at the bottom of every route tab;
- sorts route tabs and donor names;
- creates an `Unassigned` tab if a pending donor has no route.

No Supabase SQL change is required for V1.7.3.7.
All previous fixes are retained.
