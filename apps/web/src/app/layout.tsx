import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'TruckerCore',
  description: 'Trucking Management System',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
