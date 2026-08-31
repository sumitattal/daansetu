# RYM_VARGANI V1.7.4.1

## Donor removal: Inform / Do Not Inform

Individual donor deletion is now available to:
- Treasurer
- Admin
- Super Admin

When Delete is clicked, a popup shows the donor and provides two choices:
1. **WhatsApp & Delete** — removes the donor from the active donor list and opens the donor's WhatsApp chat with the approved Marathi removal message pre-filled.
2. **Delete Without Informing** — removes the donor without opening WhatsApp.

If the donor has no valid mobile number, the app warns the user and offers deletion without notification.

The WhatsApp message is formatted for WhatsApp using bold text and includes the exact requested Rajasthan Yuvak Mandal wording.

Historical receipt/payment records remain preserved because donor removal continues to be a soft removal.

Run `supabase/upgrade-v1.7.4.1.sql` once in Supabase SQL Editor.
All V1.7.4.0 changes are retained.
