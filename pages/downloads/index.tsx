// TypeScript
import React from "react";
import Head from "next/head";
import Link from "next/link";

const DOWNLOADS_BASE = process.env.NEXT_PUBLIC_SUPABASE_URL
  ? `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/downloads`
  : "https://your-project.supabase.co/storage/v1/object/public/downloads";

const downloads = [
  {
    name: "TruckerCore Desktop (Windows)",
    file: "TruckerCore.appinstaller",
    description: "Windows 10/11 installer with auto-updates",
    icon: "💻",
  },
  {
    name: "TruckerCore Mobile (Android APK)",
    file: "TruckerCore.apk",
    description: "Direct APK for sideloading (beta testing)",
    icon: "📱",
  },
  {
    name: "TruckerCore SDK",
    file: "truckercore-sdk-1.0.0.zip",
    description: "TypeScript/JavaScript SDK for integrations",
    icon: "🔧",
  },
];

export default function Downloads() {
  return (
    <>
      <Head>
        <title>Downloads – TruckerCore</title>
        <meta name="description" content="Download TruckerCore desktop and mobile apps" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
      </Head>

      <main style={styles.main}>
        <div style={styles.container}>
          <h1 style={styles.title}>Downloads</h1>
          <p style={styles.subtitle}>
            Get TruckerCore on your desktop, mobile device, or integrate with our SDK
          </p>

          <div style={styles.grid}>
            {downloads.map((item) => (
              <DownloadCard key={item.file} {...item} />
            ))}
          </div>

          <div style={styles.footer}>
            <p>Need help? <Link href="/contact">Contact support</Link></p>
            <p><Link href="/">← Back to homepage</Link></p>
          </div>
        </div>
      </main>
    </>
  );
}

interface DownloadCardProps {
  name: string;
  file: string;
  description: string;
  icon: string;
}

const DownloadCard: React.FC<DownloadCardProps> = ({ name, file, description, icon }) => {
  const downloadUrl = `${DOWNLOADS_BASE}/${file}`;

  return (
    <div style={styles.card}>
      <div style={styles.icon}>{icon}</div>
      <h3 style={styles.cardTitle}>{name}</h3>
      <p style={styles.cardDescription}>{description}</p>
      <a href={downloadUrl} style={styles.downloadButton} download>
        Download
      </a>
    </div>
  );
};

const styles: Record<string, React.CSSProperties> = {
  main: {
    minHeight: "100vh",
    background: "linear-gradient(135deg, #0F1216 0%, #1A1F26 100%)",
    color: "#FFFFFF",
    padding: "48px 24px",
  },
  container: {
    maxWidth: "1200px",
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
    gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
    gap: "24px",
    marginBottom: "48px",
  },
  card: {
    backgroundColor: "#1A1F26",
    border: "1px solid #2A313A",
    borderRadius: "12px",
    padding: "24px",
    textAlign: "center",
    transition: "transform 0.2s, border-color 0.2s",
  },
  icon: {
    fontSize: "3rem",
    marginBottom: "16px",
  },
  cardTitle: {
    fontSize: "1.25rem",
    fontWeight: 600,
    marginBottom: "8px",
  },
  cardDescription: {
    fontSize: "0.95rem",
    color: "#B0B8C0",
    marginBottom: "16px",
    lineHeight: 1.5,
  },
  downloadButton: {
    display: "inline-block",
    padding: "10px 24px",
    fontSize: "0.95rem",
    fontWeight: 600,
    color: "#000000",
    backgroundColor: "#58A6FF",
    borderRadius: "6px",
    textDecoration: "none",
    transition: "background-color 0.2s",
  },
  footer: {
    textAlign: "center",
    fontSize: "0.9rem",
    color: "#6E7681",
    marginTop: "48px",
  },
};