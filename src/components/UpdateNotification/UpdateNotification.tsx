import React, { useEffect, useState } from 'react';
import './UpdateNotification.css';

interface UpdateNotificationProps {
  registration?: ServiceWorkerRegistration;
}

const UpdateNotification: React.FC<UpdateNotificationProps> = ({ registration }) => {
  const [showUpdate, setShowUpdate] = useState(false);

  useEffect(() => {
    if (registration && registration.waiting) {
      setShowUpdate(true);
    }
  }, [registration]);

  const handleUpdate = () => {
    if (registration && registration.waiting) {
      registration.waiting.postMessage({ type: 'SKIP_WAITING' });
      window.location.reload();
    }
  };

  if (!showUpdate) return null;

  return (
    <div className="update-notification" role="status" aria-live="polite">
      <div className="update-content">
        <span className="update-icon" aria-hidden>🔄</span>
        <div className="update-text">
          <strong>New Version Available!</strong>
          <p>Click to update and get the latest features</p>
        </div>
        <button className="update-button" onClick={handleUpdate} aria-label="Update application now">
          Update Now
        </button>
        <button className="update-dismiss" onClick={() => setShowUpdate(false)} aria-label="Dismiss update notification">
          ×
        </button>
      </div>
    </div>
  );
};

export default UpdateNotification;
