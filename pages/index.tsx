// TypeScript
import React from "react";
import Head from "next/head";

export default function Home() {
  return (
    <>
      <Head>
        <title>TruckerCore — Safety, Compliance & Operations</title>
        <meta
          name="description"
          content="Dashboards for owner-operators, fleets, truck stops, and brokers. Safer, faster, and compliant trucking."
        />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        {/* Open Graph / social */}
        <meta property="og:title" content="TruckerCore" />
        <meta
          property="og:description"
          content="Safety Summary Suite + enterprise dashboards for modern trucking."
        />
        <meta property="og:image" content="/truckercore-logo.png" />
        <meta property="og:type" content="website" />
      </Head>

      <main style={styles.page}>
        {/* Header */}
        <header style={styles.header}>
          <div style={styles.brand}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/truckercore-logo.png"
              alt="TruckerCore logo — tire + road mark"
              width={72}
              height={72}
              style={styles.logo}
            />
            <span style={styles.brandText}>TruckerCore</span>
          </div>
          <nav aria-label="primary" style={styles.nav}>
            <a style={styles.navLink} href="https://app.truckercore.com">
              App
            </a>
            <a style={styles.navLink} href="https://downloads.truckercore.com">
              Downloads
            </a>
            <a style={styles.navLink} href="/docs">
              Docs
            </a>
          </nav>
        </header>

        {/* Hero */}
        <section style={styles.hero}>
          <h1 style={styles.h1}>Safety, Compliance & Operations — all in one place</h1>
          <p style={styles.sub}>
            Dashboards for <strong>Owner-Operators</strong>, <strong>Fleet Managers</strong>,{" "}
            <strong>Truck Stops</strong>, and <strong>Brokers</strong>. Built for real-time insights,
            exports, and enterprise-grade security.
          </p>
          <div style={styles.ctaRow}>
            <a style={{ ...styles.cta, ...styles.ctaPrimary }} href="https://app.truckercore.com">
              Launch App
            </a>
            <a
              style={{ ...styles.cta, ...styles.ctaGhost }}
              href="https://downloads.truckercore.com/storage/v1/object/public/downloads/TruckerCore.appinstaller"
            >
              Download Desktop
            </a>
          </div>
          <p style={styles.meta}>
            Need the API?{" "}
            <a style={styles.link} href="https://api.truckercore.com/health">
              api.truckercore.com
            </a>
          </p>
        </section>

        {/* Feature grid */}
        <section style={styles.grid}>
          <article style={styles.card}>
            <h3 style={styles.cardTitle}>Safety Summary Suite</h3>
            <p style={styles.cardBody}>
              Secure RLS views, scheduled refresh, CSV exports with rate-limiting and checksums.
            </p>
          </article>
          <article style={styles.card}>
            <h3 style={styles.cardTitle}>Enterprise Dashboards</h3>
            <p style={styles.cardBody}>
              Owner-Op, Fleet, Truck Stop, and Broker dashboards with role-based access.
            </p>
          </article>
          <article style={styles.card}>
            <h3 style={styles.cardTitle}>Desktop + Auto-Update</h3>
            <p style={styles.cardBody}>
              Tauri shell, Windows App Installer, macOS notarized builds, Linux repos.
            </p>
          </article>
          <article style={styles.card}>
            <h3 style={styles.cardTitle}>Secure by Default</h3>
            <p style={styles.cardBody}>
              Row-level security, hardened exports, telemetry, and CI security checks.
            </p>
          </article>
        </section>

        {/* Footer */}
        <footer style={styles.footer}>
          <p>© {new Date().getFullYear()} TruckerCore • Built for the road 🚚</p>
          <p>
            <a style={styles.link} href="/privacy">
              Privacy
            </a>{" "}
            ·{" "}
            <a style={styles.link} href="/terms">
              Terms
            </a>{" "}
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
  panel: "#0f2628",
  accent: "#0fa3a6",
  text: "#eaf4f4",
  sub: "#b7d4d5",
  card: "#102e31",
  border: "rgba(255,255,255,0.1)",
};

const styles: { [k: string]: React.CSSProperties } = {
  page: {
    minHeight: "100vh",
    background: `radial-gradient(1200px 600px at 10% -10%, #153a3d, ${colors.bg})`,
    color: colors.text,
    display: "flex",
    flexDirection: "column",
  },
  header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "18px 20px",
    borderBottom: `1px solid ${colors.border}`,
  },
  brand: { display: "flex", alignItems: "center", gap: 12 },
  logo: { borderRadius: 12, boxShadow: "0 4px 20px rgba(0,0,0,.25)" },
  brandText: { fontWeight: 800, letterSpacing: 0.5, fontSize: 20 },
  nav: { display: "flex", gap: 16 },
  navLink: { color: colors.sub, textDecoration: "none" },
  hero: {
    textAlign: "center",
    padding: "64px 20px 32px",
    maxWidth: 900,
    margin: "0 auto",
  },
  h1: { fontSize: 36, lineHeight: 1.2, margin: 0, fontWeight: 800 },
  sub: { color: colors.sub, marginTop: 14, fontSize: 18 },
  ctaRow: {
    display: "flex",
    gap: 12,
    justifyContent: "center",
    marginTop: 24,
    flexWrap: "wrap",
  },
  cta: {
    padding: "12px 18px",
    borderRadius: 12,
    textDecoration: "none",
    fontWeight: 700,
    border: `1px solid ${colors.border}`,
  },
  ctaPrimary: {
    background: colors.accent,
    color: "#072224",
    borderColor: "transparent",
  },
  ctaGhost: { color: colors.text },
  meta: { marginTop: 16, color: colors.sub },
  link: { color: colors.accent, textDecoration: "none" },
  grid: {
    display: "grid",
    gap: 14,
    padding: "24px 20px 60px",
    gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))",
    maxWidth: 1100,
    margin: "0 auto",
  },
  card: {
    background: colors.card,
    border: `1px solid ${colors.border}`,
    borderRadius: 14,
    padding: 18,
    boxShadow: "0 10px 30px rgba(0,0,0,.25)",
  },
  cardTitle: { margin: 0, fontSize: 18, fontWeight: 800 },
  cardBody: { color: colors.sub, marginTop: 8 },
  footer: {
    borderTop: `1px solid ${colors.border}`,
    padding: "16px 20px 28px",
    textAlign: "center",
    marginTop: "auto",
    color: colors.sub,
  },
};
