export default function Loading() {
  return (
    <div style={styles.container}>
      <div style={styles.spinner}></div>
      <p style={styles.text}>Loading...</p>
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
    backgroundColor: '#0F1216',
    color: '#ffffff',
  },
  spinner: {
    width: '48px',
    height: '48px',
    border: '4px solid #2A313A',
    borderTop: '4px solid #58A6FF',
    borderRadius: '50%',
    animation: 'spin 1s linear infinite',
  },
  text: {
    marginTop: '16px',
    fontSize: '16px',
    color: '#8B949E',
  },
};
