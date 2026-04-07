import React from 'react';
import ReactDOM from 'react-dom/client';
import './App.css';
import './print.css';
import App from './App';
import * as serviceWorkerRegistration from './serviceWorkerRegistration';

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// Register service worker for PWA support with update hooks
serviceWorkerRegistration.register({
  onSuccess: () => {
    console.log('✅ App is ready for offline use!');
  },
  onUpdate: (registration) => {
    console.log('🔄 New version available!');
    if (window.confirm('New version available! Reload to update?')) {
      if (registration.waiting) {
        registration.waiting.postMessage({ type: 'SKIP_WAITING' });
        window.location.reload();
      }
    }
  },
});
