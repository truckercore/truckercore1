'use client';

import { useEffect, useState } from 'react';
import { Line, Bar, Doughnut } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

interface AnalyticsData {
  pageViews: Record<string, number>;
  featureUsage: Record<string, number>;
  errors: Array<{ name: string; count: number }>;
  userActivity: Array<{ date: string; events: number }>;
  performanceSummary: {
    averages: {
      cpu: string;
      memory: string;
      networkLatency: string;
    };
  };
}

export default function AnalyticsDashboard() {
  const [analyticsData, setAnalyticsData] = useState<AnalyticsData | null>(null);
  const [timeRange, setTimeRange] = useState<'24h' | '7d' | '30d'>('7d');

  useEffect(() => {
    loadAnalytics();
  }, [timeRange]);

  const loadAnalytics = async () => {
    // Placeholder mock data; in a real app, request from backend or IPC
    const mockData: AnalyticsData = {
      pageViews: {
        'Fleet Manager': 150,
        'Owner Operator': 89,
        'Freight Broker': 45,
        'Truck Stop': 32,
      },
      featureUsage: {
        'Live Tracking': 245,
        'Route Planning': 178,
        'Expense Tracking': 134,
        'Load Posting': 89,
        'IFTA Report': 56,
      },
      errors: [
        { name: 'Network Error', count: 12 },
        { name: 'API Timeout', count: 8 },
        { name: 'Database Error', count: 3 },
      ],
      userActivity: [
        { date: '2025-09-25', events: 450 },
        { date: '2025-09-26', events: 520 },
        { date: '2025-09-27', events: 480 },
        { date: '2025-09-28', events: 610 },
        { date: '2025-09-29', events: 590 },
        { date: '2025-09-30', events: 670 },
        { date: '2025-10-01', events: 720 },
      ],
      performanceSummary: {
        averages: { cpu: '45.2', memory: '62.8', networkLatency: '85' },
      },
    };

    setAnalyticsData(mockData);
  };

  if (!analyticsData) {
    return (
      <div className="flex items-center justify-center min-h-[60vh] bg-gray-900 text-white">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
          <p>Loading analytics...</p>
        </div>
      </div>
    );
  }

  const pageViewsData = {
    labels: Object.keys(analyticsData.pageViews),
    datasets: [
      {
        label: 'Page Views',
        data: Object.values(analyticsData.pageViews),
        backgroundColor: ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6'],
      },
    ],
  };

  const featureUsageData = {
    labels: Object.keys(analyticsData.featureUsage),
    datasets: [
      {
        label: 'Feature Usage',
        data: Object.values(analyticsData.featureUsage),
        backgroundColor: '#3b82f6',
      },
    ],
  };

  const userActivityData = {
    labels: analyticsData.userActivity.map((d) => d.date),
    datasets: [
      {
        label: 'Events',
        data: analyticsData.userActivity.map((d) => d.events),
        borderColor: '#10b981',
        backgroundColor: 'rgba(16, 185, 129, 0.1)',
        fill: true,
      },
    ],
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6">
      <div className="mb-6 flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold mb-2">Analytics Dashboard</h1>
          <p className="text-gray-400">Application usage and performance metrics</p>
        </div>
        <div className="flex space-x-2">
          {(['24h', '7d', '30d'] as const).map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-4 py-2 rounded font-semibold transition ${
                timeRange === range ? 'bg-blue-600' : 'bg-gray-800 hover:bg-gray-700'
              }`}
            >
              {range}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
          <div className="text-sm text-gray-400 mb-1">Average CPU Usage</div>
          <div className="text-3xl font-bold">{analyticsData.performanceSummary.averages.cpu}%</div>
          <div className="mt-2 w-full bg-gray-700 rounded-full h-2">
            <div className="bg-blue-500 h-2 rounded-full" style={{ width: `${analyticsData.performanceSummary.averages.cpu}%` }} />
          </div>
        </div>
        <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
          <div className="text-sm text-gray-400 mb-1">Average Memory Usage</div>
          <div className="text-3xl font-bold">{analyticsData.performanceSummary.averages.memory}%</div>
          <div className="mt-2 w-full bg-gray-700 rounded-full h-2">
            <div className="bg-green-500 h-2 rounded-full" style={{ width: `${analyticsData.performanceSummary.averages.memory}%` }} />
          </div>
        </div>
        <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
          <div className="text-sm text-gray-400 mb-1">Network Latency</div>
          <div className="text-3xl font-bold">{analyticsData.performanceSummary.averages.networkLatency}ms</div>
          <div className="text-sm text-green-400 mt-2">Good</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
          <h3 className="text-xl font-bold mb-4">Page Views by Role</h3>
          <Doughnut data={pageViewsData} options={{ maintainAspectRatio: true }} />
        </div>
        <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
          <h3 className="text-xl font-bold mb-4">Top Features</h3>
          <Bar data={featureUsageData} options={{ maintainAspectRatio: true }} />
        </div>
      </div>

      <div className="bg-gray-800 p-6 rounded-lg border border-gray-700 mb-6">
        <h3 className="text-xl font-bold mb-4">User Activity Trend</h3>
        <Line data={userActivityData} options={{ maintainAspectRatio: true }} />
      </div>

      <div className="bg-gray-800 p-6 rounded-lg border border-gray-700">
        <h3 className="text-xl font-bold mb-4">Recent Errors</h3>
        <div className="space-y-3">
          {analyticsData.errors.map((error, index) => (
            <div key={index} className="flex justify-between items-center p-3 bg-gray-700 rounded">
              <div className="flex items-center">
                <div className="w-2 h-2 bg-red-500 rounded-full mr-3"></div>
                <span className="font-semibold">{error.name}</span>
              </div>
              <span className="text-gray-400">{error.count} occurrences</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
