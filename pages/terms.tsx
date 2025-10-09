// TypeScript
import React from "react";
import Head from "next/head";
import Link from "next/link";

export default function Terms() {
  return (
    <>
      <Head>
        <title>Terms of Service — TruckerCore</title>
        <meta name="description" content="TruckerCore terms of service and usage agreement." />
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
          <h1 style={styles.h1}>Terms of Service</h1>
          <p style={styles.updated}>Last updated: {new Date().toLocaleDateString()}</p>

          <section style={styles.section}>
            <h2 style={styles.h2}>1. Acceptance of Terms</h2>
            <p style={styles.p}>
              By accessing or using TruckerCore ("the Service"), you agree to be bound by these Terms of
              Service. If you do not agree, do not use the Service.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>2. Service Description</h2>
            <p style={styles.p}>
              TruckerCore provides safety, compliance, and operations dashboards for the trucking industry,
              including:
            </p>
            <ul style={styles.list}>
              <li>Real-time safety alerts and route planning</li>
              <li>Fleet management and HOS tracking</li>
              <li>Broker and truck stop dashboards</li>
              <li>Compliance automation and reporting</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>3. User Accounts</h2>
            <p style={styles.p}>You are responsible for:</p>
            <ul style={styles.list}>
              <li>Maintaining the security of your account credentials</li>
              <li>All activities that occur under your account</li>
              <li>Notifying us immediately of any unauthorized access</li>
              <li>Providing accurate and complete registration information</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>4. Acceptable Use</h2>
            <p style={styles.p}>You agree not to:</p>
            <ul style={styles.list}>
              <li>Use the Service for any illegal purpose</li>
              <li>Attempt to gain unauthorized access to our systems</li>
              <li>Interfere with or disrupt the Service</li>
              <li>Reverse engineer or decompile any part of the Service</li>
              <li>Share your account credentials with others</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>5. Subscription and Billing</h2>
            <p style={styles.p}>
              <strong>Free Tier:</strong> Limited to 20 active loads, 3 chat threads, 3 boosted listings/month.
            </p>
            <p style={styles.p}>
              <strong>Pro Tier ($149/month):</strong> Unlimited loads, AI matching, e-sign, compliance
              automation.
            </p>
            <p style={styles.p}>
              Subscriptions renew automatically. Cancel anytime in account settings. No refunds for partial
              months.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>6. Data Ownership and Export</h2>
            <p style={styles.p}>
              You retain ownership of your data. You may export data at any time via CSV or API. We retain
              data for 90 days after account deletion for backup purposes.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>7. Disclaimer of Warranties</h2>
            <p style={styles.p}>
              THE SERVICE IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED. We do not
              guarantee uptime, accuracy of safety alerts, or fitness for a particular purpose.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>8. Limitation of Liability</h2>
            <p style={styles.p}>
              TruckerCore shall not be liable for any indirect, incidental, or consequential damages arising
              from use of the Service, including but not limited to accidents, delays, or compliance
              violations.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>9. Indemnification</h2>
            <p style={styles.p}>
              You agree to indemnify and hold harmless TruckerCore from any claims arising from your use of
              the Service or violation of these Terms.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>10. Changes to Terms</h2>
            <p style={styles.p}>
              We may modify these Terms at any time. Continued use after changes constitutes acceptance. We
              will notify users of material changes via email.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>11. Termination</h2>
            <p style={styles.p}>
              We reserve the right to suspend or terminate accounts that violate these Terms or engage in
              fraudulent activity. You may cancel your account at any time.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>12. Governing Law</h2>
            <p style={styles.p}>
              These Terms are governed by the laws of [Your Jurisdiction]. Disputes will be resolved in
              [Your Jurisdiction] courts.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.h2}>13. Contact</h2>
            <p style={styles.p}>
              For questions about these Terms, contact: {" "}
              <a style={styles.link} href="mailto:legal@truckercore.com">
                legal@truckercore.com
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
            <Link href="/privacy" style={styles.link}>
              Privacy
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