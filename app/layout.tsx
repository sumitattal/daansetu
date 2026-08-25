import type { Metadata, Viewport } from 'next'
import './globals.css'
import PwaRegister from './pwa-register'

export const metadata: Metadata = {
  title: 'DaanSetu — Donation Management',
  description: 'Bilingual multi-organization donation and collection management',
  manifest: '/manifest.webmanifest',
  appleWebApp: { capable: true, title: 'DaanSetu', statusBarStyle: 'default' },
  icons: { apple: '/icon-192.png' }
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#173d34'
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body><PwaRegister />{children}</body>
    </html>
  )
}
