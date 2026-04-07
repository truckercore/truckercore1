import React, { useEffect, useState } from 'react';
import './OfflineIndicator.css';

const OfflineIndicator: React.FC = () => {
  const [isOnline, setIsOnline] = useState<boolean>(navigator.onLine);

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  if (isOnline) return null;

  return (
    <div className="offline-indicator" role="status" aria-live="polite">
      <div className="offline-content">
        <span className="offline-icon" aria-hidden>📴</span>
        <span className="offline-text">You are currently offline</span>
      </div>
    </div>
  );
};

export default OfflineIndicator;
