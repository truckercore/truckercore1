import Link from 'next/link';

export default function NotFound() {
  return (
    <div style={styles.container}>
      <h1 style={styles.title}>404</h1>
      <h2 style={styles.subtitle}>Page Not Found</h2>
      <p style={styles.description}>
        The page you're looking for doesn't exist or has been moved.
      </p>
      <div style={styles.links}>
        <Link href="/" style={styles.primaryLink}>
          Go Home
        </Link>
        <Link href="https://app.truckercore.com" style={styles.secondaryLink}>
          Launch App
        </Link>
      </div>
    </div>
  );
}

const styles: { [key: string]: React.CSSProperties } = {
  container: {
    minHeight: '100vh',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '24px',
    backgroundColor: '#0F1216',
    color: '#ffffff',
    textAlign: 'center',
  },
  title: {
    fontSize: '96px',
    fontWeight: 700,
    background: 'linear-gradient(135deg, #58A6FF 0%, #79C0FF 100%)',
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
    backgroundClip: 'text',
    marginBottom: '16px',
  },
  subtitle: {
    fontSize: '32px',
    fontWeight: 600,
    marginBottom: '16px',
    color: '#ffffff',
  },
  description: {
    fontSize: '18px',
    color: '#8B949E',
    marginBottom: '32px',
    maxWidth: '500px',
  },
  links: {
    display: 'flex',
    gap: '16px',
    flexWrap: 'wrap',
    justifyContent: 'center',
  },
  primaryLink: {
    padding: '14px 32px',
    backgroundColor: '#58A6FF',
    color: '#000',
    borderRadius: '8px',
    fontWeight: 600,
    fontSize: '16px',
    transition: 'all 0.2s',
  },
  secondaryLink: {
    padding: '14px 32px',
    border: '2px solid #58A6FF',
    color: '#58A6FF',
    borderRadius: '8px',
    fontWeight: 600,
    fontSize: '16px',
    transition: 'all 0.2s',
  },
};
