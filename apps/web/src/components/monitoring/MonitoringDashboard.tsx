import React, { useEffect, useMemo, useState } from 'react';
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
} from 'chart.js';

import { DefaultStorageMonitor, StorageMetrics } from '../../services/storage/implementations/DefaultStorageMonitor';
import { exportService } from '../../services/ExportService';
import { notificationService, NotificationPriority, NotificationType } from '../../services/NotificationService';

ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  BarElement,
  ArcElement,
  Title,
  Tooltip,
  Legend
);

interface HistoricalDataPoint {
  timestamp: number;
  totalOperations: number;
  successfulOperations: number;
  failedOperations: number;
  averageLatency: number;
}

export const MonitoringDashboard: React.FC = () => {
  const [metrics, setMetrics] = useState<StorageMetrics | null>(null);
  const [historicalData, setHistoricalData] = useState<HistoricalDataPoint[]>([]);
  const [refreshInterval, setRefreshInterval] = useState(2000);
  const [isPaused, setIsPaused] = useState(false);

  // Alerts configuration (simple thresholds)
  const [p95LatencyThreshold, setP95LatencyThreshold] = useState<number>(500);
  const [errorRateThreshold, setErrorRateThreshold] = useState<number>(5); // percent
  const [alertsEnabled, setAlertsEnabled] = useState<boolean>(true);
  const [webhookEnabled, setWebhookEnabled] = useState<boolean>(true);
  const webhookUrl = typeof process !== 'undefined' ? (process.env.NEXT_PUBLIC_MONITORING_WEBHOOK_URL || '') : '';
  const [lastAlertAt, setLastAlertAt] = useState<number>(0);
  const alertCooldownMs = 60_000; // throttle alerts to at most once per minute

  useEffect(() => {
    const monitor = DefaultStorageMonitor.getInstance();

    const update = () => {
      if (isPaused) return;
      const current = monitor.getMetrics();
      setMetrics(current);
      setHistoricalData((prev) => {
        const point: HistoricalDataPoint = {
          timestamp: Date.now(),
          totalOperations: current.totalOperations,
          successfulOperations: current.successfulOperations,
          failedOperations: current.failedOperations,
          averageLatency: current.averageLatency,
        };
        return [...prev, point].slice(-60);
      });
    };

    update();
    const id = setInterval(update, refreshInterval);
    return () => clearInterval(id);
  }, [refreshInterval, isPaused]);

  // Evaluate thresholds and emit alerts (best-effort)
  const checkAlerts = (m: StorageMetrics) => {
    if (!alertsEnabled) return;
    const now = Date.now();
    if (now - lastAlertAt < alertCooldownMs) return;

    // Calculate p95 from operation latencies aggregate (approximate using max of per-op p95)
    const p95s: number[] = Object.values(m.operationLatencies)
      .map((s) => (typeof s.p95 === 'number' ? (s.p95 as number) : 0))
      .filter((v) => v > 0);
    const p95 = p95s.length ? Math.max(...p95s) : 0;
    const errPct = m.totalOperations > 0 ? (m.failedOperations / m.totalOperations) * 100 : 0;

    const breaches: string[] = [];
    if (p95ThresholdBreached(p95)) breaches.push(`p95 latency ${p95.toFixed(0)}ms > ${p95LatencyThreshold}ms`);
    if (errorRateBreached(errPct)) breaches.push(`error rate ${errPct.toFixed(1)}% > ${errorRateThreshold}%`);

    if (breaches.length > 0) {
      setLastAlertAt(now);
      const title = 'Storage Monitoring Alert';
      const message = breaches.join(' • ');
      // In-app notification (admin/user-1 for demo)
      notificationService.createNotification('admin', {
        type: NotificationType.ALERT,
        priority: NotificationPriority.CRITICAL,
        title,
        message,
      });
      // Optional webhook
      if (webhookEnabled && webhookUrl) {
        try {
          fetch(webhookUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              event: 'monitoring.alert',
              title,
              message,
              metrics: {
                totalOperations: m.totalOperations,
                failedOperations: m.failedOperations,
                errorRate: errPct,
                p95,
              },
              at: new Date().toISOString(),
            }),
          }).catch(() => void 0);
        } catch (_) {}
      }
    }
  };

  const p95ThresholdBreached = (p95: number) => p95LatencyThreshold > 0 && p95 > p95LatencyThreshold;
  const errorRateBreached = (errPct: number) => errorRateThreshold > 0 && errPct > errorRateThreshold;

  if (!metrics) {
    return (
      <div className="monitoring-dashboard loading">
        <div className="spinner">Loading metrics...</div>
      </div>
    );
  }

  return (
    <div className="monitoring-dashboard">
      <DashboardHeader
        isPaused={isPaused}
        onTogglePause={() => setIsPaused(!isPaused)}
        refreshInterval={refreshInterval}
        onRefreshIntervalChange={setRefreshInterval}
        onReset={() => DefaultStorageMonitor.getInstance().reset()}
      />

      <SummaryCards metrics={metrics} />

      {/* Export & Alert Controls */}
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 12 }}>
        <button
          className="btn"
          onClick={async () => {
            // Export current aggregated metrics to JSON
            await exportService.export({ format: 'json', data: [metrics], filename: 'storage-metrics.json' });
          }}
          aria-label="Export JSON"
        >
          Export JSON
        </button>
        <button
          className="btn"
          onClick={async () => {
            // Flatten operation stats for CSV
            const rows = Object.entries(metrics.operationLatencies).map(([op, s]) => ({
              operation: op,
              count: metrics.operationCounts[op] ?? 0,
              min: s.min,
              max: s.max,
              avg: s.average,
              p50: s.p50 ?? 0,
              p95: s.p95 ?? 0,
              p99: s.p99 ?? 0,
            }));
            await exportService.export({ format: 'csv', data: rows, filename: 'storage-ops.csv' });
          }}
          aria-label="Export CSV"
        >
          Export CSV
        </button>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 8, alignItems: 'center' }}>
          <label style={{ fontSize: 12, color: '#64748b' }}>Alerts</label>
          <input type="checkbox" checked={alertsEnabled} onChange={(e) => setAlertsEnabled(e.currentTarget.checked)} aria-label="Enable alerts" />
          <label style={{ fontSize: 12, color: '#64748b' }}>p95&gt;</label>
          <input
            type="number"
            value={p95LatencyThreshold}
            onChange={(e) => setP95LatencyThreshold(Number(e.currentTarget.value))}
            style={{ width: 80 }}
            aria-label="p95 threshold"
          />
          <label style={{ fontSize: 12, color: '#64748b' }}>ms</label>
          <label style={{ fontSize: 12, color: '#64748b', marginLeft: 8 }}>Err%&gt;</label>
          <input
            type="number"
            value={errorRateThreshold}
            onChange={(e) => setErrorRateThreshold(Number(e.currentTarget.value))}
            style={{ width: 60 }}
            aria-label="Error rate threshold"
          />
          <label style={{ fontSize: 12, color: '#64748b', marginLeft: 8 }}>Webhook</label>
          <input type="checkbox" checked={webhookEnabled} onChange={(e) => setWebhookEnabled(e.currentTarget.checked)} aria-label="Enable webhook" />
        </div>
      </div>

      <div className="charts-grid">
        <LatencyChart historicalData={historicalData} />
        <OperationsChart historicalData={historicalData} />
        <OperationBreakdownChart metrics={metrics} />
        <SuccessRateChart metrics={metrics} />
      </div>

      <OperationDetailsTable />
    </div>
  );
};

const DashboardHeader: React.FC<{
  isPaused: boolean;
  onTogglePause: () => void;
  refreshInterval: number;
  onRefreshIntervalChange: (interval: number) => void;
  onReset: () => void;
}> = ({ isPaused, onTogglePause, refreshInterval, onRefreshIntervalChange, onReset }) => {
  return (
    <div className="dashboard-header">
      <div className="header-left">
        <h1>📊 Storage Performance Monitor</h1>
        <span className="subtitle">Real-time metrics and analytics</span>
      </div>

      <div className="header-controls">
        <button className={`btn ${isPaused ? 'btn-success' : 'btn-warning'}`} onClick={onTogglePause}>
          {isPaused ? '▶️ Resume' : '⏸️ Pause'}
        </button>

        <select
          value={refreshInterval}
          onChange={(e) => onRefreshIntervalChange(Number(e.target.value))}
          className="refresh-selector"
          aria-label="Refresh interval"
        >
          <option value={1000}>1s refresh</option>
          <option value={2000}>2s refresh</option>
          <option value={5000}>5s refresh</option>
          <option value={10000}>10s refresh</option>
        </select>

        <button
          className="btn btn-danger"
          onClick={() => {
            if (window.confirm('Reset all metrics? This cannot be undone.')) onReset();
          }}
        >
          🔄 Reset
        </button>
      </div>
    </div>
  );
};

const SummaryCards: React.FC<{ metrics: StorageMetrics }> = ({ metrics }) => {
  const successRate = metrics.totalOperations > 0 ? (metrics.successfulOperations / metrics.totalOperations) * 100 : 100;

  const cards = [
    {
      title: 'Total Operations',
      value: metrics.totalOperations.toLocaleString(),
      icon: '📊',
      color: '#3b82f6',
      trend: metrics.totalOperations > 0 ? 'up' : 'neutral',
    },
    {
      title: 'Success Rate',
      value: `${successRate.toFixed(1)}%`,
      icon: '✅',
      color: successRate > 95 ? '#10b981' : successRate > 80 ? '#f59e0b' : '#ef4444',
      trend: successRate > 95 ? 'up' : successRate > 80 ? 'neutral' : 'down',
    },
    {
      title: 'Average Latency',
      value: `${metrics.averageLatency.toFixed(1)}ms`,
      icon: '⚡',
      color: metrics.averageLatency < 100 ? '#10b981' : metrics.averageLatency < 500 ? '#f59e0b' : '#ef4444',
      trend: metrics.averageLatency < 100 ? 'up' : 'down',
    },
    {
      title: 'Failed Operations',
      value: metrics.failedOperations.toLocaleString(),
      icon: '❌',
      color: metrics.failedOperations === 0 ? '#10b981' : '#ef4444',
      trend: metrics.failedOperations === 0 ? 'up' : 'down',
    },
  ] as const;

  return (
    <div className="summary-cards">
      {cards.map((c, idx) => (
        <SummaryCard key={idx} title={c.title} value={c.value} icon={c.icon} color={c.color} trend={c.trend as any} />
      ))}
    </div>
  );
};

export const SummaryCard: React.FC<{
  title: string;
  value: string;
  icon: string;
  color: string;
  trend: 'up' | 'down' | 'neutral';
}> = ({ title, value, icon, color, trend }) => {
  const trendIcon = trend === 'up' ? '📈' : trend === 'down' ? '📉' : '➖';
  return (
    <div className="summary-card" style={{ borderColor: color }}>
      <div className="card-icon" style={{ color }}>
        {icon}
      </div>
      <div className="card-content">
        <div className="card-title">{title}</div>
        <div className="card-value" style={{ color }}>
          {value}
        </div>
      </div>
      <div className="card-trend">{trendIcon}</div>
    </div>
  );
};

const LatencyChart: React.FC<{ historicalData: HistoricalDataPoint[] }> = ({ historicalData }) => {
  const data = useMemo(() => ({
    labels: historicalData.map((d) => new Date(d.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })),
    datasets: [
      {
        label: 'Average Latency (ms)',
        data: historicalData.map((d) => d.averageLatency),
        borderColor: 'rgb(59, 130, 246)',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        tension: 0.4,
        fill: true,
      },
    ],
  }), [historicalData]);

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { position: 'top' as const }, title: { display: true, text: 'Latency Over Time' } },
    scales: { y: { beginAtZero: true, title: { display: true, text: 'Milliseconds' } } },
  };

  return (
    <div className="chart-container">
      <Line data={data} options={options} />
    </div>
  );
};

const OperationsChart: React.FC<{ historicalData: HistoricalDataPoint[] }> = ({ historicalData }) => {
  const data = useMemo(() => ({
    labels: historicalData.map((d) => new Date(d.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })),
    datasets: [
      {
        label: 'Successful',
        data: historicalData.map((d) => d.successfulOperations),
        borderColor: 'rgb(16, 185, 129)',
        backgroundColor: 'rgba(16, 185, 129, 0.5)',
        stack: 'operations',
      },
      {
        label: 'Failed',
        data: historicalData.map((d) => d.failedOperations),
        borderColor: 'rgb(239, 68, 68)',
        backgroundColor: 'rgba(239, 68, 68, 0.5)',
        stack: 'operations',
      },
    ],
  }), [historicalData]);

  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { position: 'top' as const }, title: { display: true, text: 'Operations Over Time' } },
    scales: { y: { stacked: true, beginAtZero: true, title: { display: true, text: 'Count' } }, x: { stacked: true } },
  };

  return (
    <div className="chart-container">
      <Bar data={data} options={options} />
    </div>
  );
};

const OperationBreakdownChart: React.FC<{ metrics: StorageMetrics }> = ({ metrics }) => {
  const entries = Object.entries(metrics.operationCounts);
  if (entries.length === 0) {
    return (
      <div className="chart-container chart-empty">
        <p>No operations recorded yet</p>
      </div>
    );
  }

  const data = {
    labels: entries.map(([op]) => op),
    datasets: [
      {
        label: 'Operations',
        data: entries.map(([, c]) => c),
        backgroundColor: [
          'rgba(59, 130, 246, 0.7)',
          'rgba(16, 185, 129, 0.7)',
          'rgba(245, 158, 11, 0.7)',
          'rgba(239, 68, 68, 0.7)',
          'rgba(139, 92, 246, 0.7)',
          'rgba(236, 72, 153, 0.7)',
        ],
        borderColor: [
          'rgb(59, 130, 246)',
          'rgb(16, 185, 129)',
          'rgb(245, 158, 11)',
          'rgb(239, 68, 68)',
          'rgb(139, 92, 246)',
          'rgb(236, 72, 153)',
        ],
        borderWidth: 2,
      },
    ],
  };

  const options = { responsive: true, maintainAspectRatio: false, plugins: { legend: { position: 'right' as const }, title: { display: true, text: 'Operations by Type' } } };
  return (
    <div className="chart-container">
      <Doughnut data={data} options={options} />
    </div>
  );
};

const SuccessRateChart: React.FC<{ metrics: StorageMetrics }> = ({ metrics }) => {
  const data = {
    labels: ['Success', 'Failed'],
    datasets: [
      {
        data: [metrics.successfulOperations, metrics.failedOperations],
        backgroundColor: ['rgba(16, 185, 129, 0.7)', 'rgba(239, 68, 68, 0.7)'],
        borderColor: ['rgb(16, 185, 129)', 'rgb(239, 68, 68)'],
        borderWidth: 2,
      },
    ],
  };
  const successRate = metrics.totalOperations > 0 ? (metrics.successfulOperations / metrics.totalOperations) * 100 : 100;
  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { position: 'bottom' as const }, title: { display: true, text: `Success Rate: ${successRate.toFixed(1)}%` } },
  };
  return (
    <div className="chart-container">
      <Doughnut data={data} options={options} />
    </div>
  );
};

const OperationDetailsTable: React.FC = () => {
  const monitor = DefaultStorageMonitor.getInstance();
  const [ops, setOps] = useState<string[]>([]);

  useEffect(() => {
    const m = monitor.getMetrics();
    setOps(Object.keys(m.operationCounts));
  }, [monitor]);

  if (ops.length === 0) {
    return (
      <div className="operations-table-empty">
        <p>No operations recorded yet. Storage operations will appear here.</p>
      </div>
    );
  }

  return (
    <div className="operations-table-container">
      <h2>📋 Operation Details</h2>
      <div className="table-wrapper">
        <table className="operations-table">
          <thead>
            <tr>
              <th>Operation</th>
              <th>Count</th>
              <th>Errors</th>
              <th>Success Rate</th>
              <th>Avg Latency</th>
              <th>Min</th>
              <th>Max</th>
              <th>P50</th>
              <th>P95</th>
              <th>P99</th>
            </tr>
          </thead>
          <tbody>
            {ops.map((operation) => {
              const s = monitor.getOperationStats(operation);
              return (
                <tr key={operation}>
                  <td className="operation-name">{operation}</td>
                  <td>{s.count}</td>
                  <td className={s.errors > 0 ? 'text-danger' : ''}>{s.errors}</td>
                  <td>
                    <span className={`badge ${s.successRate > 95 ? 'badge-success' : s.successRate > 80 ? 'badge-warning' : 'badge-danger'}`}>
                      {s.successRate.toFixed(1)}%
                    </span>
                  </td>
                  <td>{s.latency.average.toFixed(2)}ms</td>
                  <td>{s.latency.min.toFixed(2)}ms</td>
                  <td>{s.latency.max.toFixed(2)}ms</td>
                  <td>{s.latency.p50?.toFixed(2) ?? 'N/A'}ms</td>
                  <td>{s.latency.p95?.toFixed(2) ?? 'N/A'}ms</td>
                  <td>{s.latency.p99?.toFixed(2) ?? 'N/A'}ms</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default MonitoringDashboard;
