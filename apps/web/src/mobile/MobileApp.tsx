import React, { useState } from 'react';
import { DashboardInstance } from '../types/dashboard.types';
import { MobileDashboardView } from './components/MobileDashboardView';
import { MobileLogin } from './components/MobileLogin';

interface AppState {
  isAuthenticated: boolean;
  userId: string | null;
  dashboards: DashboardInstance[];
  selectedDashboard: DashboardInstance | null;
}

export const MobileApp: React.FC = () => {
  const [state, setState] = useState<AppState>({
    isAuthenticated: false,
    userId: null,
    dashboards: [],
    selectedDashboard: null,
  });

  const handleLogin = async (username: string, password: string) => {
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });

      if (response.ok) {
        const { userId, token } = await response.json();
        localStorage.setItem('authToken', token);
        setState((prev) => ({ ...prev, isAuthenticated: true, userId }));
        await loadDashboards(userId);
      } else {
        throw new Error('Auth failed');
      }
    } catch (error) {
      console.error('Login failed:', error);
      alert('Login failed. Please try again.');
    }
  };

  const loadDashboards = async (userId: string) => {
    try {
      const response = await fetch(`/api/dashboards?userId=${userId}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('authToken')}` },
      });
      if (response.ok) {
        const dashboards = await response.json();
        setState((prev) => ({ ...prev, dashboards, selectedDashboard: dashboards[0] || null }));
      }
    } catch (error) {
      console.error('Failed to load dashboards:', error);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('authToken');
    setState({ isAuthenticated: false, userId: null, dashboards: [], selectedDashboard: null });
  };

  if (!state.isAuthenticated) {
    return <MobileLogin onLogin={handleLogin} />;
  }

  return (
    <div className="min-h-screen bg-gray-100">
      <header className="bg-white shadow-sm fixed top-0 left-0 right-0 z-10">
        <div className="px-4 py-3 flex items-center justify-between">
          <h1 className="text-lg font-semibold">Dashboard Viewer</h1>
          <button onClick={handleLogout} className="text-sm text-gray-600 hover:text-gray-900">
            Logout
          </button>
        </div>
        <div className="px-4 pb-3 overflow-x-auto">
          <div className="flex gap-2">
            {state.dashboards.map((dashboard) => (
              <button
                key={dashboard.id}
                onClick={() => setState((prev) => ({ ...prev, selectedDashboard: dashboard }))}
                className={`px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap ${
                  state.selectedDashboard?.id === dashboard.id ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700'
                }`}
              >
                {dashboard.name}
              </button>
            ))}
          </div>
        </div>
      </header>

      <main className="pt-32 pb-4 px-4">
        {state.selectedDashboard ? (
          <MobileDashboardView dashboard={state.selectedDashboard} />
        ) : (
          <div className="flex items-center justify-center h-64 text-gray-500">
            <p>No dashboards available</p>
          </div>
        )}
      </main>
    </div>
  );
};
