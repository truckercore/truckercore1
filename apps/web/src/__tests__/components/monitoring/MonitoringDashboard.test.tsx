import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MonitoringDashboard } from '@/components/monitoring/MonitoringDashboard';
import DefaultStorageMonitor from '@/services/storage/implementations/DefaultStorageMonitor';

// Mock Chart.js to avoid canvas errors
vi.mock('react-chartjs-2', () => ({
  Line: ({ data }: any) => <div data-testid="line-chart">{JSON.stringify(data)}</div>,
  Bar: ({ data }: any) => <div data-testid="bar-chart">{JSON.stringify(data)}</div>,
  Doughnut: ({ data }: any) => <div data-testid="doughnut-chart">{JSON.stringify(data)}</div>,
}));

describe('MonitoringDashboard', () => {
  let monitor: ReturnType<typeof DefaultStorageMonitor.getInstance>;

  beforeEach(() => {
    monitor = DefaultStorageMonitor.getInstance();
    monitor.reset();
  });

  describe('rendering', () => {
    it('should render dashboard header', async () => {
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/Storage Performance Monitor/i)).toBeInTheDocument();
      });
    });

    it('should render all summary cards', async () => {
      monitor.recordOperation('test', 100, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText('Total Operations')).toBeInTheDocument();
        expect(screen.getByText('Success Rate')).toBeInTheDocument();
        expect(screen.getByText('Average Latency')).toBeInTheDocument();
        expect(screen.getByText('Failed Operations')).toBeInTheDocument();
      });
    });

    it('should render all chart types', async () => {
      monitor.recordOperation('test', 100, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByTestId('line-chart')).toBeInTheDocument();
        expect(screen.getByTestId('bar-chart')).toBeInTheDocument();
        expect(screen.getAllByTestId('doughnut-chart')).toHaveLength(2);
      });
    });

    it('should render operations table with data', async () => {
      monitor.recordOperation('saveFavorites', 50, true);
      monitor.recordOperation('loadFavorites', 30, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText('saveFavorites')).toBeInTheDocument();
        expect(screen.getByText('loadFavorites')).toBeInTheDocument();
      });
    });

    it('should show empty state when no operations', async () => {
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/No operations recorded yet/i)).toBeInTheDocument();
      });
    });
  });

  describe('metrics display', () => {
    it('should display correct total operations', async () => {
      monitor.recordOperation('test1', 100, true);
      monitor.recordOperation('test2', 200, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        const metrics = monitor.getMetrics();
        expect(screen.getByText(metrics.totalOperations.toString())).toBeInTheDocument();
      });
    });

    it('should calculate and display success rate', async () => {
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 100, false); // 66.7% success
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/66\.7%/)).toBeInTheDocument();
      });
    });

    it('should display average latency', async () => {
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 200, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/150\.0ms/)).toBeInTheDocument();
      });
    });

    it('should display failed operations count', async () => {
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 100, false);
      monitor.recordOperation('test', 100, false);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        const metrics = monitor.getMetrics();
        expect(screen.getByText(metrics.failedOperations.toString())).toBeInTheDocument();
      });
    });
  });

  describe('controls', () => {
    it('should toggle pause/resume', async () => {
      const user = userEvent.setup();
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/Pause/i)).toBeInTheDocument();
      });
      const pauseButton = screen.getByText(/Pause/i);
      await user.click(pauseButton);
      expect(screen.getByText(/Resume/i)).toBeInTheDocument();
    });

    it('should change refresh interval', async () => {
      const user = userEvent.setup();
      render(<MonitoringDashboard />);
      await waitFor(() => {
        const select = screen.getByRole('combobox');
        expect(select).toBeInTheDocument();
      });
      const select = screen.getByRole('combobox') as HTMLSelectElement;
      await user.selectOptions(select, '5000');
      expect(select.value).toBe('5000');
    });

    it('should show confirmation before reset', async () => {
      const user = userEvent.setup();
      // @ts-ignore
      global.confirm = vi.fn(() => true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/Reset/i)).toBeInTheDocument();
      });
      const resetButton = screen.getByText(/Reset/i);
      await user.click(resetButton);
      expect(global.confirm).toHaveBeenCalledWith(expect.stringContaining('Reset all metrics'));
    });

    it('should not reset if confirmation cancelled', async () => {
      const user = userEvent.setup();
      // @ts-ignore
      global.confirm = vi.fn(() => false);
      monitor.recordOperation('test', 100, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/Reset/i)).toBeInTheDocument();
      });
      const resetButton = screen.getByText(/Reset/i);
      await user.click(resetButton);
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(1); // Not reset
    });
  });

  describe('real-time updates', () => {
    it('should update metrics automatically', async () => {
      vi.useFakeTimers();
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText('0')).toBeInTheDocument();
      });
      monitor.recordOperation('test', 100, true);
      vi.advanceTimersByTime(2000);
      await waitFor(() => {
        expect(screen.getByText('1')).toBeInTheDocument();
      });
      vi.useRealTimers();
    });

    it('should stop updates when paused', async () => {
      vi.useFakeTimers();
      const user = userEvent.setup({ delay: null });
      render(<MonitoringDashboard />);
      await waitFor(() => {
        expect(screen.getByText(/Pause/i)).toBeInTheDocument();
      });
      const pauseButton = screen.getByText(/Pause/i);
      await user.click(pauseButton);
      monitor.recordOperation('test', 100, true);
      vi.advanceTimersByTime(5000);
      const metrics = monitor.getMetrics();
      expect(metrics.totalOperations).toBe(1);
      vi.useRealTimers();
    });
  });

  describe('status indicators', () => {
    it('should show good status for high success rate', async () => {
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 100, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        const badge = screen.getByText(/100\.0%/);
        expect(badge.className).toContain('success');
      });
    });

    it('should show warning status for medium success rate', async () => {
      monitor.recordOperation('test', 100, true);
      monitor.recordOperation('test', 100, false);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        const badge = screen.getByText(/50\.0%/);
        expect(badge.className).toContain('warning');
      });
    });

    it('should show error status for low success rate', async () => {
      monitor.recordOperation('test', 100, false);
      monitor.recordOperation('test', 100, false);
      monitor.recordOperation('test', 100, true);
      render(<MonitoringDashboard />);
      await waitFor(() => {
        const badge = screen.getByText(/33\.3%/);
        expect(badge.className).toContain('danger');
      });
    });
  });

  describe('historical data', () => {
    it('should accumulate historical data points', async () => {
      vi.useFakeTimers();
      render(<MonitoringDashboard />);
      for (let i = 0; i < 5; i++) {
        monitor.recordOperation('test', 100 + i * 10, true);
        vi.advanceTimersByTime(2000);
      }
      await waitFor(() => {
        const lineChart = screen.getByTestId('line-chart');
        const chartData = JSON.parse(lineChart.textContent || '{}');
        expect(chartData.datasets[0].data.length).toBeGreaterThan(1);
      });
      vi.useRealTimers();
    });

    it('should limit historical data to 60 points', async () => {
      vi.useFakeTimers();
      render(<MonitoringDashboard />);
      for (let i = 0; i < 70; i++) {
        monitor.recordOperation('test', 100, true);
        vi.advanceTimersByTime(2000);
      }
      await waitFor(() => {
        const lineChart = screen.getByTestId('line-chart');
        const chartData = JSON.parse(lineChart.textContent || '{}');
        expect(chartData.datasets[0].data.length).toBeLessThanOrEqual(60);
      });
      vi.useRealTimers();
    });
  });
});
