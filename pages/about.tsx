// TypeScript
import React from "react";
import Head from "next/head";
import Link from "next/link";

export default function About() {
  return (
    <>
      <Head>
        <title>About – TruckerCore</title>
        <meta name="description" content="Learn more about TruckerCore" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>

      <main style={styles.main}>
        <div style={styles.container}>
          <h1 style={styles.title}>About TruckerCore</h1>
          
          <section style={styles.section}>
            <h2 style={styles.heading}>Our Mission</h2>
            <p style={styles.text}>
              TruckerCore is building the smartest platform for professional truckers, 
              owner-operators, and freight brokers. We combine real-time safety alerts, 
              intelligent route planning, and fleet management tools to help you move 
              freight safer, faster, and more profitably.
            </p>
          </section>

          <section style={styles.section}>
            <h2 style={styles.heading}>What We Do</h2>
            <ul style={styles.list}>
              <li>Real-time crowd-sourced hazard alerts</li>
              <li>Truck-optimized routing with low-bridge and restriction data</li>
              <li>Hours of Service (HOS) tracking and compliance automation</li>
              <li>Detention analytics and profitability insights</li>
              <li>Load marketplace with AI-powered matching</li>
              <li>E-sign and automated compliance workflows</li>
            </ul>
          </section>

          <section style={styles.section}>
            <h2 style={styles.heading}>Built for Truckers, by Truckers</h2>
            <p style={styles.text}>
              Our team includes former fleet managers, owner-operators, and logistics 
              professionals who understand the daily challenges of moving freight. 
              Every feature is designed to solve real problems faced on the road.
            </p>
          </section>

          <div style={styles.cta}>
            <Link href="https://app.truckercore.com" style={styles.button}>
              Get Started
            </Link>
            <Link href="/contact" style={styles.linkButton}>
              Contact Us
            </Link>
          </div>

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
    maxWidth: "800px",
    margin: "0 auto",
  },
  title: {
    fontSize: "2.5rem",
    fontWeight: 700,
    marginBottom: "48px",
  },
  section: {
    marginBottom: "48px",
  },
  heading: {
    fontSize: "1.75rem",
    fontWeight: 600,
    marginBottom: "16px",
    color: "#58A6FF",
  },
  text: {
    fontSize: "1.1rem",
    lineHeight: 1.7,
    color: "#B0B8C0",
  },
  list: {
    fontSize: "1.1rem",
    lineHeight: 1.9,
    color: "#B0B8C0",
    paddingLeft: "24px",
  },
  cta: {
    display: "flex",
    gap: "16px",
    marginTop: "48px",
    marginBottom: "24px",
  },
  button: {
    padding: "14px 32px",
    fontSize: "1rem",
    fontWeight: 600,
    color: "#000000",
    backgroundColor: "#58A6FF",
    borderRadius: "8px",
    textDecoration: "none",
  },
  linkButton: {
    padding: "14px 32px",
    fontSize: "1rem",
    fontWeight: 600,
    color: "#FFFFFF",
    backgroundColor: "transparent",
    border: "2px solid #58A6FF",
    borderRadius: "8px",
    textDecoration: "none",
  },
  footer: {
    marginTop: "48px",
    fontSize: "0.9rem",
    color: "#6E7681",
  },
};