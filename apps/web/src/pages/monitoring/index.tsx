'use client';

import { useEffect, useState } from 'react';

export default function MonitoringDashboard() {
  const [metrics, setMetrics] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchMetrics();
    const interval = setInterval(fetchMetrics, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchMetrics = async () => {
    try {
      const response = await fetch('/api/metrics/summary');
      const data = await response.json();
      setMetrics(data);
    } catch (error) {
      console.error('Failed to fetch metrics:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="loading">Loading metrics...</div>;
  }

  if (!metrics) {
    return <div className="error">Failed to load metrics</div>;
    }

  return (
    <div className="monitoring-dashboard">
      <h1>API Monitoring Dashboard</h1>

      <div className="metrics-grid">
        <MetricCard
          title="Total Requests"
          value={metrics.totalRequests?.toLocaleString?.() || '0'}
          subtitle={`Last ${metrics.timeWindow / 60} minutes`}
        />
        <MetricCard
          title="Error Rate"
          value={`${(metrics.errorRate || 0).toFixed(2)}%`}
          subtitle={`${metrics.errorCount || 0} errors`}
          status={(metrics.errorRate || 0) > 5 ? 'error' : 'success'}
        />
        <MetricCard
          title="Avg Response Time"
          value={`${(metrics.avgDuration || 0).toFixed(0)}ms`}
          subtitle="Average duration"
        />
        <MetricCard
          title="P95 Response Time"
          value={`${(metrics.p95Duration || 0).toFixed(0)}ms`}
          subtitle="95th percentile"
          status={(metrics.p95Duration || 0) > 1000 ? 'warning' : 'success'}
        />
      </div>

      <div className="endpoints-table">
        <h2>Endpoint Performance</h2>
        <table>
          <thead>
            <tr>
              <th>Endpoint</th>
              <th>Requests</th>
              <th>Avg Duration</th>
              <th>Errors</th>
              <th>Error Rate</th>
            </tr>
          </thead>
          <tbody>
            {metrics.endpoints
              ?.sort?.((a: any, b: any) => (b.count || 0) - (a.count || 0))
              ?.slice?.(0, 10)
              ?.map?.((endpoint: any) => (
                <tr key={endpoint.endpoint}>
                  <td>{endpoint.endpoint}</td>
                  <td>{endpoint.count}</td>
                  <td>{(endpoint.avgDuration || 0).toFixed(0)}ms</td>
                  <td>{endpoint.errors}</td>
                  <td>{(((endpoint.errors || 0) / (endpoint.count || 1)) * 100).toFixed(1)}%</td>
                </tr>
              ))}
          </tbody>
        </table>
      </div>

      <style jsx>{`
        .monitoring-dashboard { max-width: 1400px; margin: 0 auto; padding: 20px; }
        h1 { font-size: 32px; font-weight: 700; margin-bottom: 30px; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .endpoints-table { background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .endpoints-table h2 { margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e5e7eb; }
        th { font-weight: 600; color: #374151; background: #f9fafb; }
      `}</style>
    </div>
  );
}

function MetricCard({ title, value, subtitle, status = 'normal' }: { title: string; value: string; subtitle: string; status?: 'normal' | 'success' | 'warning' | 'error'; }) {
  return (
    <div className={`metric-card ${status}`}>
      <div className="metric-title">{title}</div>
      <div className="metric-value">{value}</div>
      <div className="metric-subtitle">{subtitle}</div>

      <style jsx>{`
        .metric-card { background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); border-left: 4px solid #e5e7eb; }
        .metric-card.success { border-left-color: #10b981; }
        .metric-card.warning { border-left-color: #f59e0b; }
        .metric-card.error { border-left-color: #ef4444; }
        .metric-title { font-size: 14px; color: #6b7280; margin-bottom: 8px; }
        .metric-value { font-size: 32px; font-weight: 700; margin-bottom: 4px; }
        .metric-subtitle { font-size: 14px; color: #9ca3af; }
      `}</style>
    </div>
  );
}
