// TypeScript
import React from "react";
import Head from "next/head";
import Link from "next/link";

export default function Contact() {
  return (
    <>
      <Head>
        <title>Contact Us – TruckerCore</title>
        <meta name="description" content="Get in touch with TruckerCore support" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>

      <main style={styles.main}>
        <div style={styles.container}>
          <h1 style={styles.title}>Contact Us</h1>
          <p style={styles.subtitle}>
            Have questions? We're here to help.
          </p>

          <div style={styles.grid}>
            <div style={styles.card}>
              <div style={styles.icon}>📧</div>
              <h3 style={styles.cardTitle}>Email Support</h3>
              <p style={styles.cardText}>
                <a href="mailto:support@truckercore.com" style={styles.link}>
                  support@truckercore.com
                </a>
              </p>
              <p style={styles.cardMeta}>Response within 24 hours</p>
            </div>

            <div style={styles.card}>
              <div style={styles.icon}>💬</div>
              <h3 style={styles.cardTitle}>Live Chat</h3>
              <p style={styles.cardText}>
                Available in-app<br />
                Mon-Fri, 8am-6pm ET
              </p>
              <a href="https://app.truckercore.com" style={styles.button}>
                Open App
              </a>
            </div>

            <div style={styles.card}>
              <div style={styles.icon}>📞</div>
              <h3 style={styles.cardTitle}>Phone</h3>
              <p style={styles.cardText}>
                <a href="tel:+18005551234" style={styles.link}>
                  1-800-555-1234
                </a>
              </p>
              <p style={styles.cardMeta}>Mon-Fri, 9am-5pm ET</p>
            </div>

            <div style={styles.card}>
              <div style={styles.icon}>🏢</div>
              <h3 style={styles.cardTitle}>Mailing Address</h3>
              <p style={styles.cardText}>
                TruckerCore Inc.<br />
                [Your Business Address]<br />
                [City, State ZIP]
              </p>
            </div>
          </div>

          <section style={styles.section}>
            <h2 style={styles.heading}>Frequently Asked Questions</h2>
            <div style={styles.faq}>
              <div style={styles.faqItem}>
                <strong>How do I sign up?</strong>
                <p>Visit <a href="https://app.truckercore.com" style={styles.link}>app.truckercore.com</a> and click "Sign Up".</p>
              </div>
              <div style={styles.faqItem}>
                <strong>What's included in the free plan?</strong>
                <p>20 active loads, 3 chat threads, 3 boosted listings per month, and basic safety alerts.</p>
              </div>
              <div style={styles.faqItem}>
                <strong>How do I upgrade to Pro?</strong>
                <p>Go to Settings → Subscription in the app dashboard.</p>
              </div>
              <div style={styles.faqItem}>
                <strong>Can I cancel anytime?</strong>
                <p>Yes, cancel anytime from your account settings. No long-term contracts.</p>
              </div>
            </div>
          </section>

          <div style={styles.footer}>
            <Link href="/">← Back to homepage</Link>
          </div>
        </div>
      </main>
    </>
  );
}

const styles: Record<string, React.CSSProperties> = {
  main: {
    minHeight: "100vh",
    background: "linear-gradient(135deg, #0F1216 0%, #1A1F26 100%)",
    color: "#FFFFFF",
    padding: "48px 24px",
  },
  container: {
    maxWidth: "1000px",
    margin: "0 auto",
  },
  title: {
    fontSize: "2.5rem",
    fontWeight: 700,
    marginBottom: "12px",
    textAlign: "center",
  },
  subtitle: {
    fontSize: "1.1rem",
    color: "#B0B8C0",
    textAlign: "center",
    marginBottom: "48px",
  },
  grid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fit, minmax(250px, 1fr))",
    gap: "24px",
    marginBottom: "48px",
  },
  card: {
    backgroundColor: "#1A1F26",
    border: "1px solid #2A313A",
    borderRadius: "12px",
    padding: "24px",
    textAlign: "center",
  },
  icon: {
    fontSize: "2.5rem",
    marginBottom: "12px",
  },
  cardTitle: {
    fontSize: "1.25rem",
    fontWeight: 600,
    marginBottom: "12px",
  },
  cardText: {
    fontSize: "1rem",
    color: "#B0B8C0",
    marginBottom: "8px",
  },
  cardMeta: {
    fontSize: "0.85rem",
    color: "#6E7681",
  },
  link: {
    color: "#58A6FF",
    textDecoration: "underline",
  },
  button: {
    display: "inline-block",
    marginTop: "12px",
    padding: "10px 20px",
    fontSize: "0.95rem",
    fontWeight: 600,
    color: "#000000",
    backgroundColor: "#58A6FF",
    borderRadius: "6px",
    textDecoration: "none",
  },
  section: {
    marginTop: "48px",
    marginBottom: "48px",
  },
  heading: {
    fontSize: "1.75rem",
    fontWeight: 600,
    marginBottom: "24px",
    color: "#58A6FF",
  },
  faq: {
    display: "flex",
    flexDirection: "column",
    gap: "24px",
  },
  faqItem: {
    paddingLeft: "16px",
    borderLeft: "3px solid #58A6FF",
  },
  footer: {
    marginTop: "48px",
    textAlign: "center",
    fontSize: "0.9rem",
    color: "#6E7681",
  },
};