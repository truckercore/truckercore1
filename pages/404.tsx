// TypeScript
import React from "react";
import Head from "next/head";
import Link from "next/link";
import { useRouter } from "next/router";

export default function NotFound() {
  const router = useRouter();

  return (
    <>
      <Head>
        <title>404 – Page Not Found | TruckerCore</title>
        <meta name="description" content="The page you requested could not be found." />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
      </Head>

      <main style={styles.main}>
        <div style={styles.container}>
          <div style={styles.errorCode}>404</div>
          <h1 style={styles.title}>Page Not Found</h1>
          <p style={styles.subtitle}>
            The page <code style={styles.code}>{router.asPath}</code> doesn't exist.
          </p>

          <div style={styles.actions}>
            <Link href="/" style={styles.primaryButton}>
              Go to Homepage
            </Link>
            <Link href="https://app.truckercore.com" style={styles.secondaryButton}>
              Open App
            </Link>
          </div>

          <div style={styles.helpSection}>
            <h2 style={styles.helpTitle}>Looking for something specific?</h2>
            <ul style={styles.helpList}>
              <li><Link href="/about" style={styles.link}>About Us</Link></li>
              <li><Link href="/downloads" style={styles.link}>Downloads</Link></li>
              <li><Link href="/contact" style={styles.link}>Contact Support</Link></li>
              <li><Link href="/privacy" style={styles.link}>Privacy Policy</Link></li>
              <li><Link href="/terms" style={styles.link}>Terms of Service</Link></li>
            </ul>
          </div>
        </div>
      </main>
    </>
  );
}

const styles: Record<string, React.CSSProperties> = {
  main: {
    minHeight: "100vh",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: "linear-gradient(135deg, #0F1216 0%, #1A1F26 100%)",
    color: "#FFFFFF",
    padding: "24px",
  },
  container: {
    textAlign: "center",
    maxWidth: "600px",
  },
  errorCode: {
    fontSize: "6rem",
    fontWeight: 700,
    background: "linear-gradient(135deg, #58A6FF 0%, #79C0FF 100%)",
    WebkitBackgroundClip: "text",
    WebkitTextFillColor: "transparent",
    backgroundClip: "text",
    lineHeight: 1,
    marginBottom: "16px",
  },
  title: {
    fontSize: "2rem",
    fontWeight: 600,
    marginBottom: "12px",
  },
  subtitle: {
    fontSize: "1.1rem",
    color: "#B0B8C0",
    marginBottom: "32px",
  },
  code: {
    backgroundColor: "#2A313A",
    padding: "2px 8px",
    borderRadius: "4px",
    fontFamily: "monospace",
    fontSize: "0.95em",
  },
  actions: {
    display: "flex",
    gap: "16px",
    justifyContent: "center",
    marginBottom: "48px",
    flexWrap: "wrap",
  },
  primaryButton: {
    padding: "14px 32px",
    fontSize: "1rem",
    fontWeight: 600,
    color: "#000000",
    backgroundColor: "#58A6FF",
    borderRadius: "8px",
    textDecoration: "none",
  },
  secondaryButton: {
    padding: "14px 32px",
    fontSize: "1rem",
    fontWeight: 600,
    color: "#FFFFFF",
    backgroundColor: "transparent",
    border: "2px solid #58A6FF",
    borderRadius: "8px",
    textDecoration: "none",
  },
  helpSection: {
    marginTop: "48px",
    paddingTop: "24px",
    borderTop: "1px solid #2A313A",
  },
  helpTitle: {
    fontSize: "1.25rem",
    marginBottom: "16px",
    color: "#B0B8C0",
  },
  helpList: {
    listStyle: "none",
    padding: 0,
    display: "flex",
    flexDirection: "column",
    gap: "8px",
  },
  link: {
    color: "#58A6FF",
    textDecoration: "underline",
    fontSize: "1rem",
  },
};