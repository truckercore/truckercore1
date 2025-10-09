import { BrowserWindow, ipcMain, Notification } from 'electron';
// Lazy-require better-sqlite3 to avoid install failures when native build is unavailable
import * as path from 'path';

interface FleetStatus {
  truckId: string;
  driverId: string;
  status: 'active' | 'idle' | 'maintenance' | 'offline';
  location: { lat: number; lng: number; address: string };
  speed: number;
  fuel: number;
  eta: number;
  alerts: Alert[];
  hoursRemaining: number;
}

interface Alert {
  id: string;
  type: 'clearance' | 'speed' | 'hos' | 'maintenance' | 'fuel' | 'weather';
  severity: 'critical' | 'warning' | 'info';
  message: string;
  timestamp: number;
  requiresAction: boolean;
}

export class FleetManagerDashboard {
  // Database handle is optional when better-sqlite3 is unavailable
  private db: any | null = null;
  private sqliteAvailable = false;
  private mainWindow: BrowserWindow;
  private updateInterval: NodeJS.Timeout | null = null;

  constructor(mainWindow: BrowserWindow, dbPath: string) {
    this.mainWindow = mainWindow;
    const resolved = path.resolve(dbPath);
    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const BetterSqlite3 = require('better-sqlite3');
      this.db = new BetterSqlite3(resolved);
      this.sqliteAvailable = true;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('[FleetManagerDashboard] better-sqlite3 not available. Live DB features disabled.', e);
      this.db = null;
      this.sqliteAvailable = false;
    }
    this.initializeDatabase();
    this.setupHandlers();
  }

  private initializeDatabase() {
    if (!this.sqliteAvailable || !this.db) {
      return;
    }
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS fleet_live (
        truck_id TEXT PRIMARY KEY,
        driver_id TEXT,
        driver_name TEXT,
        status TEXT,
        lat REAL,
        lng REAL,
        address TEXT,
        speed REAL,
        fuel REAL,
        eta INTEGER,
        hours_remaining REAL,
        last_update INTEGER
      );

      CREATE TABLE IF NOT EXISTS fleet_alerts (
        id TEXT PRIMARY KEY,
        truck_id TEXT,
        type TEXT,
        severity TEXT,
        message TEXT,
        requires_action BOOLEAN,
        acknowledged BOOLEAN DEFAULT 0,
        created_at INTEGER,
        acknowledged_at INTEGER,
        acknowledged_by TEXT
      );

      CREATE TABLE IF NOT EXISTS dispatch_log (
        id TEXT PRIMARY KEY,
        truck_id TEXT,
        action TEXT,
        details TEXT,
        user TEXT,
        timestamp INTEGER
      );

      CREATE TABLE IF NOT EXISTS performance_metrics (
        id TEXT PRIMARY KEY,
        truck_id TEXT,
        date TEXT,
        miles_driven REAL,
        fuel_consumed REAL,
        mpg REAL,
        idle_time INTEGER,
        violations INTEGER,
        on_time_deliveries INTEGER
      );

      CREATE INDEX IF NOT EXISTS idx_alerts_unack ON fleet_alerts(acknowledged, severity) 
        WHERE acknowledged = 0;
      CREATE INDEX IF NOT EXISTS idx_truck_status ON fleet_live(status);
    `);
  }

  private setupHandlers() {
    if (!this.sqliteAvailable || !this.db) {
      // Register no-op/empty handlers so UI can still function without native module
      ipcMain.handle('fleet-manager:get-live-status', async () => {
        return [];
      });
      ipcMain.handle('fleet-manager:get-critical-alerts', async () => {
        return [];
      });
      ipcMain.handle('fleet-manager:acknowledge-alert', async () => {
        return false;
      });
      ipcMain.handle('fleet-manager:dispatch-truck', async () => {
        return { success: false, dispatchId: null };
      });
      ipcMain.handle('fleet-manager:get-performance-metrics', async () => {
        return [];
      });
      ipcMain.handle('fleet-manager:export-report', async () => {
        return { success: true, path: '' };
      });
      ipcMain.handle('fleet-manager:suggest-truck', async () => {
        return [];
      });
      ipcMain.on('fleet-manager:emergency-alert', () => {
        // no-op when DB not available
      });
      return;
    }

    // Get live fleet status
    ipcMain.handle('fleet-manager:get-live-status', async () => {
      const stmt = this.db.prepare(`
        SELECT 
          fl.*,
          COALESCE(SUM(CASE WHEN fa.acknowledged = 0 THEN 1 ELSE 0 END), 0) as unread_alerts
        FROM fleet_live fl
        LEFT JOIN fleet_alerts fa ON fl.truck_id = fa.truck_id
        GROUP BY fl.truck_id
        ORDER BY 
          CASE fl.status
            WHEN 'active' THEN 1
            WHEN 'idle' THEN 2
            WHEN 'maintenance' THEN 3
            WHEN 'offline' THEN 4
            ELSE 5
          END
      `);
      return stmt.all();
    });

    // Get critical alerts
    ipcMain.handle('fleet-manager:get-critical-alerts', async () => {
      const stmt = this.db.prepare(`
        SELECT fa.*, fl.driver_name, fl.address
        FROM fleet_alerts fa
        JOIN fleet_live fl ON fa.truck_id = fl.truck_id
        WHERE fa.acknowledged = 0 
          AND fa.severity IN ('critical', 'warning')
        ORDER BY 
          CASE fa.severity
            WHEN 'critical' THEN 1
            WHEN 'warning' THEN 2
            WHEN 'info' THEN 3
            ELSE 4
          END,
          fa.created_at DESC
      `);
      return stmt.all();
    });

    // Acknowledge alert
    ipcMain.handle('fleet-manager:acknowledge-alert', async (_event, alertId: string, userId: string) => {
      const result = this.db.prepare(`
        UPDATE fleet_alerts 
        SET acknowledged = 1, acknowledged_at = ?, acknowledged_by = ?
        WHERE id = ?
      `).run(Date.now(), userId, alertId);

      // Log action
      this.logAction(alertId, 'alert_acknowledged', userId);

      return result.changes > 0;
    });

    // Dispatch truck to new route
    ipcMain.handle('fleet-manager:dispatch-truck', async (_event, data: {
      truckId: string;
      driverId: string;
      origin: string;
      destination: string;
      priority: 'urgent' | 'normal' | 'scheduled';
      specialInstructions?: string;
      userId: string;
    }) => {
      const dispatchId = `DISP-${Date.now()}`;

      this.db.prepare(`
        INSERT INTO dispatch_log (id, truck_id, action, details, user, timestamp)
        VALUES (?, ?, ?, ?, ?, ?)
      `).run(
        dispatchId,
        data.truckId,
        'dispatch',
        JSON.stringify({
          origin: data.origin,
          destination: data.destination,
          priority: data.priority,
          specialInstructions: data.specialInstructions ?? null,
        }),
        data.userId,
        Date.now()
      );

      // Notify driver (forward to renderer to integrate with existing stack)
      this.mainWindow.webContents.send('send-driver-notification', {
        driverId: data.driverId,
        message: `New dispatch: ${data.origin} → ${data.destination}`,
        priority: data.priority,
      });

      // Desktop notification
      new Notification({
        title: 'Truck Dispatched',
        body: `Truck #${data.truckId} dispatched to ${data.destination}`,
        urgency: data.priority === 'urgent' ? 'critical' : 'normal',
      }).show();

      return { success: true, dispatchId };
    });

    // Fleet performance metrics
    ipcMain.handle('fleet-manager:get-performance-metrics', async (_event, params: {
      period: 'today' | 'week' | 'month';
      truckId?: string;
    }) => {
      const dateFilter = this.getDateFilter(params.period);

      let base = `
        SELECT 
          truck_id,
          SUM(miles_driven) as total_miles,
          SUM(fuel_consumed) as total_fuel,
          AVG(mpg) as avg_mpg,
          SUM(idle_time) as total_idle,
          SUM(violations) as total_violations,
          SUM(on_time_deliveries) as on_time_count,
          COUNT(*) as total_deliveries
        FROM performance_metrics
        WHERE date >= ?
      `;

      if (params.truckId) {
        const row = this.db.prepare(base + ' AND truck_id = ? GROUP BY truck_id').get(dateFilter, params.truckId);
        return row ?? null;
      }
      return this.db.prepare(base + ' GROUP BY truck_id').all(dateFilter);
    });

    // Export fleet report (stub)
    ipcMain.handle('fleet-manager:export-report', async (_event, params: {
      type: 'daily' | 'weekly' | 'monthly' | 'custom';
      startDate: string;
      endDate: string;
      format: 'pdf' | 'csv' | 'xlsx';
    }) => {
      const reportData = await this.generateFleetReport(params);
      return this.exportReport(reportData, params.format);
    });

    // Smart scheduling - suggest truck
    ipcMain.handle('fleet-manager:suggest-truck', async (_event, routeData: {
      origin: string; // "lat,lng"
      destination: string;
      cargo: { weight: number; height: number; hazmat: boolean };
      deadline: number;
    }) => {
      const [latStr, lngStr] = routeData.origin.split(',');
      const lat = parseFloat(latStr);
      const lng = parseFloat(lngStr);
      const stmt = this.db.prepare(`
        SELECT 
          fl.*,
          (6371 * acos(cos(radians(?)) * cos(radians(fl.lat)) * 
           cos(radians(fl.lng) - radians(?)) + 
           sin(radians(?)) * sin(radians(fl.lat)))) as distance
        FROM fleet_live fl
        WHERE fl.status = 'idle'
          AND fl.hours_remaining >= ?
        ORDER BY distance ASC
        LIMIT 5
      `);
      const availableTrucks = stmt.all(lat, lng, lat, 8);

      const scored = availableTrucks.map((t: any) => {
        const score = this.calculateTruckScore(t, routeData as any);
        return { ...t, score, reasoning: score.reasons };
      }).sort((a: any, b: any) => b.score.total - a.score.total);

      return scored;
    });

    // Emergency SOS from driver
    ipcMain.on('fleet-manager:emergency-alert', (_event, data: {
      truckId: string;
      driverId: string;
      location: { lat: number; lng: number };
      type: 'accident' | 'breakdown' | 'medical' | 'security';
    }) => {
      const alertId = `EMRG-${Date.now()}`;
      this.db.prepare(`
        INSERT INTO fleet_alerts (id, truck_id, type, severity, message, requires_action, created_at)
        VALUES (?, ?, ?, 'critical', ?, 1, ?)
      `).run(
        alertId,
        data.truckId,
        data.type,
        `🚨 EMERGENCY: ${data.type.toUpperCase()} - Truck #${data.truckId}`,
        Date.now()
      );

      const notification = new Notification({
        title: '🚨 EMERGENCY ALERT',
        body: `Driver ${data.driverId} needs help!\nType: ${data.type}\nTruck: #${data.truckId}`,
        urgency: 'critical',
        timeoutType: 'never',
        silent: false,
      });
      notification.show();
      notification.on('click', () => {
        this.mainWindow.webContents.send('navigate', `/emergency/${alertId}`);
        this.mainWindow.show();
        this.mainWindow.focus();
      });

      this.mainWindow.flashFrame(true);
      this.mainWindow.webContents.send('trigger-emergency-protocol', data);
    });
  }

  private calculateTruckScore(truck: any, routeData: any) {
    const reasons: string[] = [];
    let total = 0;

    const distanceScore = Math.max(0, 100 - (truck.distance * 2));
    total += distanceScore * 0.3;
    if (truck.distance < 50) reasons.push('Close to pickup location');

    const hoursScore = Math.min(100, (truck.hours_remaining / 11) * 100);
    total += hoursScore * 0.25;
    if (truck.hours_remaining >= 10) reasons.push('Plenty of driving hours');

    const fuelScore = (truck.fuel / 100) * 100;
    total += fuelScore * 0.15;
    if (truck.fuel > 75) reasons.push('Good fuel level');

    const perfData = this.db.prepare(`
      SELECT AVG(on_time_deliveries) as on_time_pct, AVG(violations) as avg_violations
      FROM performance_metrics
      WHERE truck_id = ? AND date >= date('now', '-30 days')
    `).get(truck.truck_id) as any;

    if (perfData) {
      const perfScore = ((perfData.on_time_pct ?? 0) * 100) - ((perfData.avg_violations ?? 0) * 10);
      total += perfScore * 0.2;
      if ((perfData.on_time_pct ?? 0) > 0.95) reasons.push('Excellent on-time delivery record');
    }

    const idleScore = truck.speed > 0 ? 100 : 50;
    total += idleScore * 0.1;

    return {
      total: Math.round(total),
      reasons,
      breakdown: {
        distance: Math.round(distanceScore),
        hours: Math.round(hoursScore),
        fuel: Math.round(fuelScore),
        performance: perfData ? Math.round(((perfData.on_time_pct ?? 0) * 100) - ((perfData.avg_violations ?? 0) * 10)) : 0,
        idle: idleScore,
      },
    };
  }

  private getDateFilter(period: string): string {
    const now = new Date();
    switch (period) {
      case 'today':
        return now.toISOString().split('T')[0];
      case 'week':
        return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      case 'month':
        return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      default:
        return now.toISOString().split('T')[0];
    }
  }

  private logAction(resourceId: string, action: string, userId: string) {
    this.db.prepare(`
      INSERT INTO dispatch_log (id, truck_id, action, details, user, timestamp)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(
      `LOG-${Date.now()}`,
      resourceId,
      action,
      '{}',
      userId,
      Date.now()
    );
  }

  private async generateFleetReport(_params: any) {
    // TODO: Implement detailed report generation
    return {};
  }

  private async exportReport(_data: any, _format: string) {
    // TODO: Implement report export (pdf/csv/xlsx)
    return { success: true, path: '' };
  }

  startLiveUpdates(intervalMs: number = 10000) {
    if (this.updateInterval) clearInterval(this.updateInterval);
    this.updateInterval = setInterval(() => {
      this.mainWindow.webContents.send('fleet-manager:live-update', {
        timestamp: Date.now(),
      });
    }, intervalMs);
  }

  stopLiveUpdates() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
  }
}
