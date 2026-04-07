import React, { useEffect, useState } from 'react';
import './App.css';
import ErrorBoundary from './components/ErrorBoundary/ErrorBoundary';
import { ToastProvider } from './contexts/ToastContext';
import UpdateNotification from './components/UpdateNotification/UpdateNotification';
import OfflineIndicator from './components/OfflineIndicator/OfflineIndicator';
import FleetDispatch from './components/FleetDispatch/FleetDispatch';
import ExpenseEntry from './components/ExpenseEntry/ExpenseEntry';
import LoadPosting from './components/LoadPosting/LoadPosting';
import PODCapture from './components/PODCapture/PODCapture';
import { perfMonitor } from './utils/performance';
import { analytics } from './utils/analytics';

// Views available in the main app
 type ViewType = 'dispatch' | 'expense' | 'posting' | 'pod';

function App() {
  const [currentView, setCurrentView] = useState<ViewType>('dispatch');
  const [isLoading, setIsLoading] = useState(true);
  const [swRegistration, setSwRegistration] = useState<ServiceWorkerRegistration>();

  useEffect(() => {
    // Log performance metrics
    perfMonitor.logPageLoad();

    // Check for service worker registration
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.ready.then((registration) => {
        setSwRegistration(registration);
      });
    }

    // Simulate initialization
    perfMonitor.startMark('app-init');
    const timer = setTimeout(() => {
      setIsLoading(false);
      perfMonitor.endMark('app-init');
    }, 500);
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    analytics.trackPageView(`/${currentView}`);
  }, [currentView]);

  useEffect(() => {
    if (process.env.NODE_ENV === 'development') {
      const interval = setInterval(() => {
        const memory = perfMonitor.getMemoryUsage();
        if (memory) {
          // eslint-disable-next-line no-console
          console.log(`💾 Memory Usage: ${memory}`);
        }
      }, 30000);
      return () => clearInterval(interval);
    }
  }, []);

  const handleViewChange = (view: ViewType) => {
    perfMonitor.startMark(`view-${view}`);
    setCurrentView(view);
    setTimeout(() => perfMonitor.endMark(`view-${view}`), 100);
  };

  const renderView = () => {
    switch (currentView) {
      case 'dispatch':
        return <FleetDispatch />;
      case 'expense':
        return <ExpenseEntry />;
      case 'posting':
        return <LoadPosting />;
      case 'pod':
        return <PODCapture />;
      default:
        return <FleetDispatch />;
    }
  };

  if (isLoading) {
    return (
      <div className="app-loading">
        <div className="spinner"></div>
        <p>Loading Freight Logistics System...</p>
        <small>v{process.env.REACT_APP_VERSION || '1.0.0'}</small>
      </div>
    );
  }

  return (
    <ErrorBoundary>
      <ToastProvider>
        <div className="app">
          <OfflineIndicator />
          <nav className="app-nav">
            <div className="nav-brand">
              <h1>🚚 Freight Logistics System</h1>
              <span className="version-badge">v{process.env.REACT_APP_VERSION || '1.0.0'}</span>
            </div>
            <div className="nav-menu">
              <button
                className={`nav-button ${currentView === 'dispatch' ? 'active' : ''}`}
                onClick={() => handleViewChange('dispatch')}
              >
                <span className="nav-icon">📊</span>
                <span>Fleet Dispatch</span>
              </button>
              <button
                className={`nav-button ${currentView === 'expense' ? 'active' : ''}`}
                onClick={() => handleViewChange('expense')}
              >
                <span className="nav-icon">💰</span>
                <span>Expense Entry</span>
              </button>
              <button
                className={`nav-button ${currentView === 'posting' ? 'active' : ''}`}
                onClick={() => handleViewChange('posting')}
              >
                <span className="nav-icon">📋</span>
                <span>Load Posting</span>
              </button>
              <button
                className={`nav-button ${currentView === 'pod' ? 'active' : ''}`}
                onClick={() => handleViewChange('pod')}
              >
                <span className="nav-icon">📸</span>
                <span>POD Capture</span>
              </button>
            </div>
          </nav>
          <main className="app-main">{renderView()}</main>
          <UpdateNotification registration={swRegistration} />
        </div>
      </ToastProvider>
    </ErrorBoundary>
  );
}

export default App;
