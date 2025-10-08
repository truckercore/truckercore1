import { app, BrowserWindow, ipcMain } from 'electron';
import * as os from 'os';
import * as fs from 'fs';
import * as path from 'path';

interface PerformanceMetrics {
  timestamp: number;
  cpu: { usage: number; loadAvg: number[] };
  memory: { used: number; total: number; percentage: number; heapUsed: number; heapTotal: number };
  disk: { used: number; total: number; percentage: number };
  network: { latency: number; status: 'online' | 'offline' };
  app: { uptime: number; windowCount: number; processMemory: NodeJS.MemoryUsage };
}

interface PerformanceAlert {
  type: 'cpu' | 'memory' | 'disk' | 'network';
  severity: 'warning' | 'critical';
  message: string;
  value: number;
  threshold: number;
  timestamp: number;
}

export class PerformanceMonitor {
  private mainWindow: BrowserWindow;
  private metricsHistory: PerformanceMetrics[] = [];
  private monitoringInterval: NodeJS.Timeout | null = null;
  private metricsFile: string;

  private readonly CPU_WARNING = 70;
  private readonly CPU_CRITICAL = 90;
  private readonly MEMORY_WARNING = 80;
  private readonly MEMORY_CRITICAL = 95;
  private readonly DISK_WARNING = 85;
  private readonly DISK_CRITICAL = 95;

  constructor(mainWindow: BrowserWindow) {
    this.mainWindow = mainWindow;
    this.metricsFile = path.join(app.getPath('userData'), 'performance-metrics.json');
    this.loadHistoricalMetrics();
    this.setupHandlers();
  }

  private setupHandlers() {
    ipcMain.handle('performance:get-current-metrics', () => this.collectMetrics());
    ipcMain.handle('performance:get-history', (_evt, duration: number) => this.getMetricsHistory(duration));
    ipcMain.handle('performance:get-summary', () => this.getPerformanceSummary());
    ipcMain.handle('performance:clear-history', () => this.clearHistory());
  }

  start(intervalMs = 5000) {
    if (this.monitoringInterval) return;
    this.monitoringInterval = setInterval(async () => {
      const metrics = await this.collectMetrics();
      this.metricsHistory.push(metrics);
      if (this.metricsHistory.length > 720) this.metricsHistory.shift();
      this.checkAlerts(metrics);
      this.mainWindow.webContents.send('performance:metrics-update', metrics);
      if (this.metricsHistory.length % 60 === 0) this.saveMetrics();
    }, intervalMs);
    // eslint-disable-next-line no-console
    console.log('[PerformanceMonitor] Started monitoring');
  }

  stop() {
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
      this.monitoringInterval = null;
      this.saveMetrics();
      // eslint-disable-next-line no-console
      console.log('[PerformanceMonitor] Stopped monitoring');
    }
  }

  private async collectMetrics(): Promise<PerformanceMetrics> {
    const cpuUsage = process.cpuUsage();
    const memoryUsage = process.memoryUsage();
    const total = os.totalmem();
    const free = os.freemem();
    const disk = await this.getDiskUsage();
    const latency = await this.measureNetworkLatency();

    return {
      timestamp: Date.now(),
      cpu: { usage: this.calculateCPUPercentage(cpuUsage), loadAvg: os.loadavg() },
      memory: {
        used: total - free,
        total,
        percentage: ((total - free) / total) * 100,
        heapUsed: memoryUsage.heapUsed,
        heapTotal: memoryUsage.heapTotal,
      },
      disk,
      network: { latency, status: latency < 5000 ? 'online' : 'offline' },
      app: { uptime: process.uptime(), windowCount: BrowserWindow.getAllWindows().length, processMemory: memoryUsage },
    };
  }

  private calculateCPUPercentage(cpu: NodeJS.CpuUsage): number {
    const totalUsage = cpu.user + cpu.system;
    return Math.min(100, (totalUsage / 1_000_000) / Math.max(1, os.cpus().length));
  }

  private async getDiskUsage(): Promise<{ used: number; total: number; percentage: number }> {
    try {
      const p = app.getPath('userData');
      const anyFs: any = fs as any;
      if (typeof anyFs.statfsSync === 'function') {
        const stats = anyFs.statfsSync(p);
        const total = stats.blocks * stats.bsize;
        const free = stats.bfree * stats.bsize;
        const used = total - free;
        return { used, total, percentage: (used / total) * 100 };
    }
    } catch (e) {
      // ignore
    }
    return { used: 0, total: 0, percentage: 0 };
  }

  private async measureNetworkLatency(): Promise<number> {
    const start = Date.now();
    try {
      // Node 18+ has global fetch
      await fetch('https://8.8.8.8', { method: 'HEAD', signal: (AbortSignal as any).timeout(5000) });
      return Date.now() - start;
    } catch {
      return 5000; // timeout/error
    }
  }

  private checkAlerts(m: PerformanceMetrics) {
    if (m.cpu.usage >= this.CPU_CRITICAL) this.emitAlert({ type: 'cpu', severity: 'critical', message: 'Critical CPU usage detected', value: m.cpu.usage, threshold: this.CPU_CRITICAL, timestamp: Date.now() });
    else if (m.cpu.usage >= this.CPU_WARNING) this.emitAlert({ type: 'cpu', severity: 'warning', message: 'High CPU usage detected', value: m.cpu.usage, threshold: this.CPU_WARNING, timestamp: Date.now() });

    if (m.memory.percentage >= this.MEMORY_CRITICAL) this.emitAlert({ type: 'memory', severity: 'critical', message: 'Critical memory usage detected', value: m.memory.percentage, threshold: this.MEMORY_CRITICAL, timestamp: Date.now() });
    else if (m.memory.percentage >= this.MEMORY_WARNING) this.emitAlert({ type: 'memory', severity: 'warning', message: 'High memory usage detected', value: m.memory.percentage, threshold: this.MEMORY_WARNING, timestamp: Date.now() });

    if (m.disk.percentage >= this.DISK_CRITICAL) this.emitAlert({ type: 'disk', severity: 'critical', message: 'Critical disk space', value: m.disk.percentage, threshold: this.DISK_CRITICAL, timestamp: Date.now() });
    else if (m.disk.percentage >= this.DISK_WARNING) this.emitAlert({ type: 'disk', severity: 'warning', message: 'Low disk space', value: m.disk.percentage, threshold: this.DISK_WARNING, timestamp: Date.now() });

    if (m.network.status === 'offline') this.emitAlert({ type: 'network', severity: 'critical', message: 'Network connection lost', value: m.network.latency, threshold: 5000, timestamp: Date.now() });
  }

  private emitAlert(alert: PerformanceAlert) {
    // eslint-disable-next-line no-console
    console.warn('[PerformanceMonitor] Alert:', alert);
    this.mainWindow.webContents.send('performance:alert', alert);
  }

  private getMetricsHistory(durationMs: number): PerformanceMetrics[] {
    const cutoff = Date.now() - durationMs;
    return this.metricsHistory.filter((m) => m.timestamp >= cutoff);
  }

  private getPerformanceSummary() {
    if (this.metricsHistory.length === 0) return null;
    const recent = this.metricsHistory.slice(-60);
    const avg = (arr: number[]) => arr.reduce((a, b) => a + b, 0) / Math.max(1, arr.length);
    const avgCPU = avg(recent.map((m) => m.cpu.usage));
    const avgMem = avg(recent.map((m) => m.memory.percentage));
    const avgLat = avg(recent.map((m) => m.network.latency));
    return { averages: { cpu: avgCPU.toFixed(2), memory: avgMem.toFixed(2), networkLatency: avgLat.toFixed(0) }, current: recent[recent.length - 1], uptime: process.uptime(), totalSamples: this.metricsHistory.length };
  }

  private saveMetrics() {
    try {
      const slice = this.metricsHistory.slice(-1000);
      fs.writeFileSync(this.metricsFile, JSON.stringify(slice, null, 2));
    } catch (e) {
      // ignore
    }
  }

  private loadHistoricalMetrics() {
    try {
      if (fs.existsSync(this.metricsFile)) {
        const data = fs.readFileSync(this.metricsFile, 'utf8');
        this.metricsHistory = JSON.parse(data);
        // eslint-disable-next-line no-console
        console.log(`[PerformanceMonitor] Loaded ${this.metricsHistory.length} historical metrics`);
      }
    } catch {
      this.metricsHistory = [];
    }
  }

  private clearHistory() {
    this.metricsHistory = [];
    try {
      if (fs.existsSync(this.metricsFile)) fs.unlinkSync(this.metricsFile);
    } catch {
      // ignore
    }
  }
}
