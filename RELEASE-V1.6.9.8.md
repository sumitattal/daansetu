# RYM_VARGANI V1.6.9.8

- Receipt > WhatsApp now opens the exact donor WhatsApp chat using the mobile number stored on the receipt.
- Indian 10-digit numbers are normalized with country code 91.
- The message is pre-filled with donor name, receipt number, amount and receipt date.
- Removed the native share-sheet dependency from the WhatsApp button, avoiding gesture/share errors and manual donor searching.
- Save & Send continues to open the donor chat after the receipt is saved.
- No Supabase migration is required.
