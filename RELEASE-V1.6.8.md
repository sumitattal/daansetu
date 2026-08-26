# RYM_VARGANI V1.6.8

- Increased receipt value font sizes while keeping long values fitted inside their allotted fields.
- Re-aligned receipt number, split date fields, donor name, mobile, PAN, amount in words, numeric amount, cheque/bank and collector name above the pre-printed lines.
- Replaced whole-page `window.print()` with a dedicated single-image receipt print window. This prevents browsers from repeating the same receipt across multiple PDF pages.
- Collection Excel now contains separate `ReceiptDate` and `CollectionDate` columns. `CollectionDate` uses Payment Received Date when available and otherwise falls back to Receipt Date.
- No Supabase schema change is required for this release.
