# RYM_VARGANI V1.6.9 — Receipt Alignment Calibration

- Recalibrated printed/PDF receipt canvas positions against the actual RYM receipt template.
- Moved donor name, mobile, PAN, amount-in-words and collector into their intended blank fields.
- Increased receipt field font sizes while fitting long text inside safe widths.
- Fully masks the template date placeholders before printing a clean DD / MM / YYYY date.
- Keeps the dedicated single-image print path from V1.6.8 to avoid duplicate PDF pages.
- No Supabase SQL upgrade required.
