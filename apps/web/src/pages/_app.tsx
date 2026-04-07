import type { AppProps } from 'next/app';
import Link from 'next/link';
import React from 'react';
import '../components/monitoring/MonitoringDashboard.css';

function App({ Component, pageProps }: AppProps) {
  const isDev = process.env.NODE_ENV !== 'production';
  return (
    <>
      <nav style={{
        position: 'sticky', top: 0, zIndex: 1000, display: 'flex', gap: 16, alignItems: 'center',
        padding: '10px 16px', background: '#0b1220', color: 'white'
      }}>
        <Link href="/" legacyBehavior>
          <a style={{ color: 'white', textDecoration: 'none' }}>🏠 Home</a>
        </Link>
        <Link href="/dashboards" legacyBehavior>
          <a style={{ color: 'white', textDecoration: 'none' }}>📊 Dashboards</a>
        </Link>
        <Link href="/monitoring" legacyBehavior>
          <a className="nav-link--monitoring" style={{ color: 'white', textDecoration: 'none' }}>📈 Monitoring</a>
        </Link>
        {isDev && (
          <span style={{ marginLeft: 'auto', fontSize: 12, opacity: 0.8 }}>DEV</span>
        )}
      </nav>
      <Component {...pageProps} />
    </>
  );
}

export default App;
