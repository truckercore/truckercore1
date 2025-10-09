// TypeScript
import React from "react";
import Head from "next/head";
import Link from "next/link";

export default function Privacy() {
  return (
    <>
      <Head>
        <title>Privacy Policy — TruckerCore</title>
        <meta name="description" content="TruckerCore privacy policy and data handling practices." />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>

      <main style={styles.page}>
        <header style={styles.header}>
          <Link href="/" style={styles.brand}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/truckercore-logo.png"
              alt="TruckerCore logo"
              width={48}
              height={48}
              style={styles.logo}
            />
            <span style={styles.brandText}>TruckerCore</span>
          </Link>
        </header>

        <article style={styles.content}>
          <h1 style={styles.h1}>Privacy Policy</h1>
          <p style={styles.updated}>Last updated: {new Date().toLocaleDateString()}</p>

          <section style={styles.section}>
            <h2 style={styles.h2}>1. Information We Collect</h2>
            <p style={styles.p}>
              TruckerCore collects information necessary to provide our safety, compliance, and operations
              dashboards. This includes:
            </p>
            <ul style={styles.list}>
              <li>Account information (email, name, organization)</li>
              <li>Location data (for route planning and safety alerts)</li>
              <li>Vehicle and load information</li>
              <li>Usage analytics (aggregated and anonymized)</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>2. How We Use Your Information</h2>
            <p style={styles.p}>We use collected information to:</p>
            <ul style={styles.list}>
              <li>Provide real-time safety alerts and route optimization</li>
              <li>Generate compliance reports and analytics</li>
              <li>Improve our services and user experience</li>
              <li>Communicate important updates and notifications</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>3. Data Security</h2>
            <p style={styles.p}>
              We implement industry-standard security measures including:
            </p>
            <ul style={styles.list}>
              <li>Row-level security (RLS) for database access</li>
              <li>Encrypted data transmission (TLS 1.3)</li>
              <li>Regular security audits and penetration testing</li>
              <li>SOC 2 Type II compliance (in progress)</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>4. Data Sharing</h2>
            <p style={styles.p}>
              We do not sell your personal information. We may share data with:
            </p>
            <ul style={styles.list}>
              <li>Service providers (hosting, analytics, email)</li>
              <li>Partners (only with your explicit consent)</li>
              <li>Legal authorities (when required by law)</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>5. Your Rights</h2>
            <p style={styles.p}>You have the right to:</p>
            <ul style={styles.list}>
              <li>Access your personal data</li>
              <li>Request data correction or deletion</li>
              <li>Opt out of marketing communications</li>
              <li>Export your data (CSV/JSON formats available)</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>6. Cookies and Tracking</h2>
            <p style={styles.p}>
              We use essential cookies for authentication and session management. Analytics cookies are
              optional and can be disabled in your account settings.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>7. Contact Us</h2>
            <p style={styles.p}>
              For privacy-related inquiries, contact us at:{" "}
              <a style={styles.link} href="mailto:privacy@truckercore.com">
                privacy@truckercore.com
              </a>
            </p>
          </section>
        </article>

        <footer style={styles.footer}>
          <p>
            <Link href="/" style={styles.link}>
              Home
            </Link>{" "}
            ·{" "}
            <Link href="/terms" style={styles.link}>
              Terms
            </Link>{" "}
            ·{" "}
            <a style={styles.link} href="mailto:engineering@truckercore.com">
              Contact
            </a>
          </p>
        </footer>
      </main>
    </>
  );
}

const colors = {
  bg: "#0e1b1c",
  accent: "#0fa3a6",
  text: "#eaf4f4",
  sub: "#b7d4d5",
  border: "rgba(255,255,255,0.1)",
};

const styles: { [k: string]: React.CSSProperties } = {
  page: {
    minHeight: "100vh",
    background: colors.bg,
    color: colors.text,
    display: "flex",
    flexDirection: "column",
  },
  header: {
    padding: "18px 20px",
    borderBottom: `1px solid ${colors.border}`,
  },
  brand: {
    display: "flex",
    alignItems: "center",
    gap: 12,
    textDecoration: "none",
    color: colors.text,
  },
  logo: { borderRadius: 8 },
  brandText: { fontWeight: 800, letterSpacing: 0.5, fontSize: 18 },
  content: {
    maxWidth: 800,
    margin: "0 auto",
    padding: "40px 20px",
  },
  h1: { fontSize: 32, fontWeight: 800, marginBottom: 8 },
  updated: { color: colors.sub, fontSize: 14, marginBottom: 32 },
  section: { marginBottom: 32 },
  h2: { fontSize: 24, fontWeight: 700, marginBottom: 12 },
  p: { color: colors.sub, lineHeight: 1.6, marginBottom: 12 },
  list: { color: colors.sub, lineHeight: 1.8, paddingLeft: 24 },
  link: { color: colors.accent, textDecoration: "none" },
  footer: {
    borderTop: `1px solid ${colors.border}`,
    padding: "16px 20px",
    textAlign: "center",
    marginTop: "auto",
    color: colors.sub,
  },
};