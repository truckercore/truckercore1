// TypeScript
import React from "react";
import Head from "next/head";
import Link from "next/link";

export default function Docs() {
  return (
    <>
      <Head>
        <title>Documentation — TruckerCore</title>
        <meta name="description" content="TruckerCore API documentation and guides." />
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
          <h1 style={styles.h1}>Documentation</h1>
          <p style={styles.p}>Coming soon — API references, integration guides, and tutorials.</p>

          <section style={styles.section}>
            <h2 style={styles.h2}>Quick Links</h2>
            <ul style={styles.list}>
              <li>
                <a style={styles.link} href="https://api.truckercore.com/health">
                  API Health Check
                </a>
              </li>
              <li>
                <a style={styles.link} href="https://app.truckercore.com">
                  Launch App
                </a>
              </li>
              <li>
                <a style={styles.link} href="https://downloads.truckercore.com">
                  Downloads
                </a>
              </li>
              <li>
                <a style={styles.link} href="mailto:engineering@truckercore.com">
                  Contact Engineering
                </a>
              </li>
            </ul>
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
            <Link href="/terms" style={styles.link}>
              Terms
            </Link>
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
  h1: { fontSize: 32, fontWeight: 800, marginBottom: 16 },
  p: { color: colors.sub, lineHeight: 1.6, marginBottom: 16 },
  section: { marginBottom: 32 },
  h2: { fontSize: 24, fontWeight: 700, marginBottom: 12 },
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