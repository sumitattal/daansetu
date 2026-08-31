# RYM_VARGANI V1.7.4.0

## Final Donation / Partial Payment correction

Collection now clearly separates **Last Year Donation** from **This Year's Final Expected Donation**.

- Collection form has **Final Donation for This Year** checked by default.
- If checked, the amount being collected becomes the donor's final current-year commitment (including any amount already collected this year).
- The donor becomes **Collected** once collected amount equals the updated current-year expected amount.
- If the payment is genuinely partial and more money is expected, uncheck **Final Donation for This Year**; the donor remains **Partial**.
- Last Year Donation is never changed by this action.
- Collection amount defaults to the current outstanding expected amount, with last year's donation only as a fallback.
- Dashboard, Route Collection, Pending list and Reports continue to use Current Expected Amount vs Collected Amount.

Run `supabase/upgrade-v1.7.4.0.sql` once in Supabase SQL Editor before using this version.
