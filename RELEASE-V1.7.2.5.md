# RYM_VARGANI V1.7.2.5 — Mobile Install Page

New public install page:

`https://daansetu.maxtechsangamner.in/install`

## Android
- Detects Android.
- Shows a large **Install RYM_VARGANI** button.
- Uses the browser `beforeinstallprompt` PWA installation prompt when Chrome provides it.
- Falls back to Chrome → menu → Install app / Add to Home screen instructions.

## iPhone / iPad
- Detects iOS/iPadOS.
- Shows Safari-specific steps:
  Share → Add to Home Screen → Add.
- Explains Apple's PWA installation limitation.

## Other
- Detects if the app is already installed in standalone mode.
- Shows **Open RYM_VARGANI**.
- Page can be shared directly on WhatsApp.
- No Supabase migration required.
