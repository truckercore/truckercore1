import React from 'react';

export const metadata = {
  title: 'TruckerCore Fleet',
  description: 'Fleet maintenance demo (App Router)',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ fontFamily: 'system-ui, sans-serif', background: '#0f1216', color: '#e6e6e6' }}>
        <div style={{ maxWidth: 1000, margin: '0 auto' }}>
          <header style={{ padding: 16 }}>
            <h1 style={{ margin: 0 }}>TruckerCore Fleet</h1>
          </header>
          <main>{children}</main>
        </div>
      </body>
    </html>
  );
}
