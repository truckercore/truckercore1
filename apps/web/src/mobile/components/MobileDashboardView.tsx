import React, { useEffect, useState } from 'react';
import { DashboardInstance, Widget } from '../../types/dashboard.types';

interface MobileDashboardViewProps {
  dashboard: DashboardInstance;
}

export const MobileDashboardView: React.FC<MobileDashboardViewProps> = ({ dashboard }) => {
  const [refreshing, setRefreshing] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date());

  useEffect(() => {
    const interval = setInterval(() => {
      handleRefresh();
    }, 60000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleRefresh = async () => {
    setRefreshing(true);
    await new Promise((resolve) => setTimeout(resolve, 1000));
    setLastUpdated(new Date());
    setRefreshing(false);
  };

  const renderWidget = (widget: Widget) => {
    return (
      <div key={widget.id} className="bg-white rounded-lg shadow-sm p-4 mb-4">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold text-gray-900">{widget.title}</h3>
          <span className="text-xs text-gray-500">{widget.type}</span>
        </div>
        <div className="min-h-[200px] flex items-center justify-center bg-gray-50 rounded">
          <div className="text-center text-gray-400">
            <svg className="w-12 h-12 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            <p className="text-sm">Widget Preview</p>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="max-w-2xl mx-auto">
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-500">Last updated: {lastUpdated.toLocaleTimeString()}</p>
        <button
          onClick={handleRefresh}
          disabled={refreshing}
          className="inline-flex items-center px-3 py-1.5 bg-white border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
        >
          <svg className={`w-4 h-4 mr-1 ${refreshing ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh
        </button>
      </div>

      <div className="space-y-4">{dashboard.widgets.map(renderWidget)}</div>

      <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
        <div className="flex">
          <svg className="w-5 h-5 text-blue-600 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
          </svg>
          <p className="text-sm text-blue-800">
            This is a view-only dashboard. To make changes, please use the desktop version.
          </p>
        </div>
      </div>
    </div>
  );
};
