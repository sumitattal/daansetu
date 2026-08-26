# RYM_VARGANI V1.6.9.4

## Receipt date micro-adjustment

- Moves the generated receipt date exactly 4 px downward on the 1536 x 1024 receipt canvas.
- Applies the identical adjustment to the on-screen View layout and the unified export renderer used by Print/PDF and WhatsApp.
- All other receipt coordinates remain unchanged from V1.6.9.3.
- No Supabase SQL upgrade is required.
