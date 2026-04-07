import { safeStorage, app, Notification } from 'electron';
import * as crypto from 'crypto';
import * as path from 'path';

// Optional dependency: better-sqlite3; require at runtime to keep optional
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let BetterSqlite3: any = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  BetterSqlite3 = require('better-sqlite3');
} catch (_e) {
  BetterSqlite3 = null;
}

export interface SecretScope {
  vendor: string;
  permissions: string[];
  environment: 'development' | 'staging' | 'production';
  expiresAt?: Date;
}

export interface SecretVersion {
  version: number;
  value: string;
  createdAt: Date;
  expiresAt?: Date;
  rotatedBy?: string;
  active: boolean;
}

export interface RotationSchedule {
  secretKey: string;
  intervalDays: number;
  lastRotation: Date;
  nextRotation: Date;
  autoRotate: boolean;
  alertDaysBefore: number;
}

export class AdvancedSecretsManager {
  // Database handle is optional when better-sqlite3 is unavailable
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private db: any | null = null;
  private sqliteAvailable = false;
  private rotationTimers: Map<string, NodeJS.Timeout> = new Map();

  // Vendor-specific scope requirements (least privilege)
  private readonly VENDOR_SCOPES: Record<string, { read: string[]; write: string[]; admin: string[] }> = {
    samsara: {
      read: ['fleets.vehicles.location:read', 'fleets.drivers.hos:read', 'fleets.vehicles.stats:read'],
      write: ['fleets.alerts:write', 'fleets.dispatch:write'],
      admin: ['fleets.settings:write', 'fleets.users:manage'],
    },
    motive: {
      read: ['hos:read', 'dvir:read', 'vehicle:read', 'ifta:read'],
      write: ['dvir:write', 'dispatch:write'],
      admin: ['users:manage', 'settings:write'],
    },
    dat: {
      read: ['loads:search', 'rates:read', 'carriers:search'],
      write: ['loads:post', 'loads:update'],
      admin: ['account:manage'],
    },
    trimble: {
      read: ['routing:calculate', 'geocoding:query', 'maps:display'],
      write: ['routes:save'],
      admin: [],
    },
  };

  // Rotation intervals by secret type (days)
  private readonly ROTATION_INTERVALS: Record<string, number> = {
    api_key: 90,
    oauth_token: 7,
    oauth_refresh: 30,
    webhook_secret: 180,
    database_password: 90,
    encryption_key: 365,
  };

  constructor() {
    const dbPath = path.join(app.getPath('userData'), 'secrets-advanced.db');
    if (BetterSqlite3) {
      try {
        this.db = new BetterSqlite3(dbPath);
        this.sqliteAvailable = true;
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error('[AdvancedSecretsManager] Failed to open sqlite DB:', e);
        this.db = null;
        this.sqliteAvailable = false;
      }
    }
    this.initializeDatabase();
    this.loadRotationSchedules();
  }

  private initializeDatabase(): void {
    if (!this.sqliteAvailable || !this.db) return;
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS secrets (
        key TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        vendor TEXT,
        environment TEXT NOT NULL,
        current_version INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS secret_versions (
        secret_key TEXT,
        version INTEGER,
        value_encrypted TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER,
        rotated_by TEXT,
        active BOOLEAN DEFAULT 1,
        PRIMARY KEY (secret_key, version),
        FOREIGN KEY (secret_key) REFERENCES secrets(key)
      );
      CREATE TABLE IF NOT EXISTS secret_scopes (
        secret_key TEXT,
        vendor TEXT NOT NULL,
        permissions TEXT NOT NULL,
        environment TEXT NOT NULL,
        expires_at INTEGER,
        PRIMARY KEY (secret_key, vendor),
        FOREIGN KEY (secret_key) REFERENCES secrets(key)
      );
      CREATE TABLE IF NOT EXISTS rotation_schedules (
        secret_key TEXT PRIMARY KEY,
        interval_days INTEGER NOT NULL,
        last_rotation INTEGER NOT NULL,
        next_rotation INTEGER NOT NULL,
        auto_rotate BOOLEAN DEFAULT 1,
        alert_days_before INTEGER DEFAULT 7,
        FOREIGN KEY (secret_key) REFERENCES secrets(key)
      );
      CREATE TABLE IF NOT EXISTS rotation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        secret_key TEXT NOT NULL,
        old_version INTEGER,
        new_version INTEGER,
        rotated_at INTEGER NOT NULL,
        rotated_by TEXT,
        reason TEXT,
        FOREIGN KEY (secret_key) REFERENCES secrets(key)
      );
      CREATE TABLE IF NOT EXISTS access_audit (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        secret_key TEXT NOT NULL,
        accessed_at INTEGER NOT NULL,
        accessed_by TEXT NOT NULL,
        purpose TEXT,
        scopes_used TEXT,
        FOREIGN KEY (secret_key) REFERENCES secrets(key)
      );
      CREATE INDEX IF NOT EXISTS idx_rotation_next ON rotation_schedules(next_rotation);
      CREATE INDEX IF NOT EXISTS idx_access_audit_time ON access_audit(accessed_at DESC);
    `);
  }

  async setSecret(
    key: string,
    value: string,
    options: {
      type: 'api_key' | 'oauth_token' | 'oauth_refresh' | 'webhook_secret' | 'database_password';
      vendor?: string;
      environment?: 'development' | 'staging' | 'production';
      scopes?: SecretScope[];
      autoRotate?: boolean;
      expiresInDays?: number;
    }
  ): Promise<void> {
    if (!this.sqliteAvailable || !this.db) return; // no-op when DB not available
    const environment = options.environment || ((process.env.NODE_ENV as any) || 'development');
    const enc = this.encrypt(value);
    const now = Date.now();
    const expiresAt = options.expiresInDays ? now + options.expiresInDays * 24 * 60 * 60 * 1000 : undefined;

    const existing = this.db.prepare('SELECT * FROM secrets WHERE key = ?').get(key);
    if (existing) {
      const currentVersion = existing.current_version as number;
      const newVersion = currentVersion + 1;
      this.db.prepare('UPDATE secret_versions SET active = 0 WHERE secret_key = ? AND version = ?').run(key, currentVersion);
      this.db
        .prepare(
          'INSERT INTO secret_versions (secret_key, version, value_encrypted, created_at, expires_at, active) VALUES (?, ?, ?, ?, ?, 1)'
        )
        .run(key, newVersion, enc, now, expiresAt || null);
      this.db
        .prepare('UPDATE secrets SET current_version = ?, updated_at = ?, type = ?, vendor = ?, environment = ? WHERE key = ?')
        .run(newVersion, now, options.type, options.vendor || null, environment, key);
      this.db
        .prepare('INSERT INTO rotation_history (secret_key, old_version, new_version, rotated_at, reason) VALUES (?, ?, ?, ?, ?)')
        .run(key, currentVersion, newVersion, now, 'manual_update');
    } else {
      this.db
        .prepare('INSERT INTO secrets (key, type, vendor, environment, current_version, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?)')
        .run(key, options.type, options.vendor || null, environment, now, now);
      this.db
        .prepare('INSERT INTO secret_versions (secret_key, version, value_encrypted, created_at, expires_at, active) VALUES (?, 1, ?, ?, ?, 1)')
        .run(key, enc, now, expiresAt || null);
    }

    if (options.scopes) {
      for (const s of options.scopes) this.setScope(key, s);
    }

    const rotationInterval = this.ROTATION_INTERVALS[options.type] || 90;
    const autoRotate = options.autoRotate !== false;
    this.db
      .prepare(
        'INSERT OR REPLACE INTO rotation_schedules (secret_key, interval_days, last_rotation, next_rotation, auto_rotate) VALUES (?, ?, ?, ?, ?)'
      )
      .run(key, rotationInterval, now, now + rotationInterval * 24 * 60 * 60 * 1000, autoRotate ? 1 : 0);

    this.scheduleRotationCheck(key, rotationInterval);
  }

  async getSecret(key: string, requiredScopes: string[], purpose: string, accessedBy = 'system'): Promise<string | null> {
    if (!this.sqliteAvailable || !this.db) return null;
    const row = this.db
      .prepare(
        'SELECT s.*, sv.value_encrypted, sv.expires_at FROM secrets s JOIN secret_versions sv ON s.key = sv.secret_key AND s.current_version = sv.version WHERE s.key = ? AND sv.active = 1'
      )
      .get(key);
    if (!row) return null;

    const currentEnv = ((process.env.NODE_ENV as any) || 'development');
    if (row.environment !== currentEnv) return null;

    if (row.expires_at && Date.now() > row.expires_at) return null;

    if (requiredScopes?.length) {
      const ok = await this.validateScopes(key, requiredScopes);
      if (!ok) throw new Error(`Insufficient permissions for secret: ${key}`);
    }

    this.db
      .prepare('INSERT INTO access_audit (secret_key, accessed_at, accessed_by, purpose, scopes_used) VALUES (?, ?, ?, ?, ?)')
      .run(key, Date.now(), accessedBy, purpose, JSON.stringify(requiredScopes || []));

    return this.decrypt(row.value_encrypted as string);
  }

  async rotateSecret(key: string, newValue: string, rotatedBy = 'system'): Promise<void> {
    if (!this.sqliteAvailable || !this.db) return; // no-op
    const secret = this.db.prepare('SELECT * FROM secrets WHERE key = ?').get(key);
    if (!secret) throw new Error(`Secret '${key}' not found`);
    const currentVersion = secret.current_version as number;
    const newVersion = currentVersion + 1;
    const now = Date.now();
    const enc = this.encrypt(newValue);

    this.db.prepare('UPDATE secret_versions SET active = 0 WHERE secret_key = ? AND version = ?').run(key, currentVersion);
    this.db
      .prepare('INSERT INTO secret_versions (secret_key, version, value_encrypted, created_at, rotated_by, active) VALUES (?, ?, ?, ?, ?, 1)')
      .run(key, newVersion, enc, now, rotatedBy);
    this.db.prepare('UPDATE secrets SET current_version = ?, updated_at = ? WHERE key = ?').run(newVersion, now, key);

    const schedule = this.db.prepare('SELECT * FROM rotation_schedules WHERE secret_key = ?').get(key);
    if (schedule) {
      const nextRotation = now + schedule.interval_days * 24 * 60 * 60 * 1000;
      this.db
        .prepare('UPDATE rotation_schedules SET last_rotation = ?, next_rotation = ? WHERE secret_key = ?')
        .run(now, nextRotation, key);
      this.scheduleRotationCheck(key, schedule.interval_days);
    }

    this.db
      .prepare('INSERT INTO rotation_history (secret_key, old_version, new_version, rotated_at, rotated_by, reason) VALUES (?, ?, ?, ?, ?, ?)')
      .run(key, currentVersion, newVersion, now, rotatedBy, 'manual_rotation');

    new Notification({ title: '🔄 Secret Rotated', body: `Secret '${key}' has been rotated successfully`, urgency: 'normal' as any }).show();
  }

  getRotationStatus(): Array<{ key: string; lastRotation: Date; nextRotation: Date; daysUntilRotation: number; status: 'ok' | 'warning' | 'overdue' }> {
    if (!this.sqliteAvailable || !this.db) return [];
    const schedules = this.db.prepare('SELECT * FROM rotation_schedules').all();
    const now = Date.now();
    return schedules.map((s: any) => {
      const daysUntil = Math.floor((s.next_rotation - now) / (24 * 60 * 60 * 1000));
      let status: 'ok' | 'warning' | 'overdue' = 'ok';
      if (daysUntil < 0) status = 'overdue';
      else if (daysUntil <= (s.alert_days_before ?? 7)) status = 'warning';
      return { key: s.secret_key, lastRotation: new Date(s.last_rotation), nextRotation: new Date(s.next_rotation), daysUntilRotation: daysUntil, status };
    });
  }

  getVendorScopes(vendor: string, level: 'read' | 'write' | 'admin' = 'read'): string[] {
    const v = this.VENDOR_SCOPES[vendor?.toLowerCase?.()];
    if (!v) return [];
    if (level === 'admin') return [...v.read, ...v.write, ...v.admin];
    if (level === 'write') return [...v.read, ...v.write];
    return v.read;
  }

  private setScope(key: string, scope: SecretScope): void {
    if (!this.sqliteAvailable || !this.db) return;
    if (scope.vendor) {
      const vendorScopes = this.VENDOR_SCOPES[scope.vendor.toLowerCase?.() || ''];
      if (vendorScopes) {
        const allowed = new Set([...vendorScopes.read, ...vendorScopes.write, ...vendorScopes.admin]);
        for (const p of scope.permissions) {
          if (!allowed.has(p)) {
            // eslint-disable-next-line no-console
            console.warn(`[Secrets] Unknown permission '${p}' for vendor ${scope.vendor}`);
          }
        }
      }
    }
    this.db
      .prepare('INSERT OR REPLACE INTO secret_scopes (secret_key, vendor, permissions, environment, expires_at) VALUES (?, ?, ?, ?, ?)')
      .run(key, scope.vendor, JSON.stringify(scope.permissions), scope.environment, scope.expiresAt ? scope.expiresAt.getTime() : null);
  }

  private async validateScopes(key: string, requiredScopes: string[]): Promise<boolean> {
    if (!this.sqliteAvailable || !this.db) return true; // cannot validate; allow
    const rows = this.db.prepare('SELECT permissions FROM secret_scopes WHERE secret_key = ?').all(key);
    if (!rows?.length) return true; // no restrictions
    const granted = new Set<string>();
    for (const r of rows) {
      try {
        const perms = JSON.parse(r.permissions as string);
        if (Array.isArray(perms)) perms.forEach((p) => granted.add(String(p)));
      } catch {}
    }
    return requiredScopes.every((req) => granted.has(req));
  }

  private scheduleRotationCheck(key: string, intervalDays: number): void {
    const existing = this.rotationTimers.get(key);
    if (existing) clearTimeout(existing);
    const checkInterval = intervalDays * 24 * 60 * 60 * 1000;
    const t = setTimeout(() => this.checkRotationDue(key), checkInterval);
    this.rotationTimers.set(key, t);
  }

  private checkRotationDue(key: string): void {
    if (!this.sqliteAvailable || !this.db) return;
    const schedule = this.db.prepare('SELECT * FROM rotation_schedules WHERE secret_key = ?').get(key);
    if (!schedule) return;
    const now = Date.now();
    const daysUntil = Math.floor((schedule.next_rotation - now) / (24 * 60 * 60 * 1000));

    if (daysUntil <= schedule.alert_days_before) {
      new Notification({ title: '⚠️ Secret Rotation Due', body: `Secret '${key}' needs rotation in ${daysUntil} days`, urgency: 'critical' as any }).show();
    }
    if (now >= schedule.next_rotation && schedule.auto_rotate) {
      // Auto-rotation not implemented for safety; require manual rotation
      new Notification({ title: '🚨 Secret Rotation Overdue', body: `Secret '${key}' is past rotation date. Manual rotation required.`, urgency: 'critical' as any }).show();
    }
  }

  private loadRotationSchedules(): void {
    if (!this.sqliteAvailable || !this.db) return;
    const schedules = this.db.prepare('SELECT * FROM rotation_schedules').all();
    for (const s of schedules) {
      const daysRemaining = Math.floor((s.next_rotation - Date.now()) / (24 * 60 * 60 * 1000));
      if (daysRemaining > 0) this.scheduleRotationCheck(s.secret_key, s.interval_days);
      else this.checkRotationDue(s.secret_key);
    }
  }

  private encrypt(value: string): string {
    if (safeStorage.isEncryptionAvailable()) {
      return safeStorage.encryptString(value).toString('base64');
    }
    const algorithm = 'aes-256-gcm';
    const key = crypto.scryptSync(process.env.ENCRYPTION_KEY || 'fallback', 'salt', 32);
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(algorithm, key, iv);
    const enc = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();
    return `${iv.toString('hex')}:${authTag.toString('hex')}:${enc.toString('hex')}`;
  }

  private decrypt(encrypted: string): string {
    if (safeStorage.isEncryptionAvailable()) {
      return safeStorage.decryptString(Buffer.from(encrypted, 'base64'));
    }
    const [ivHex, tagHex, dataHex] = encrypted.split(':');
    const algorithm = 'aes-256-gcm';
    const key = crypto.scryptSync(process.env.ENCRYPTION_KEY || 'fallback', 'salt', 32);
    const iv = Buffer.from(ivHex, 'hex');
    const tag = Buffer.from(tagHex, 'hex');
    const data = Buffer.from(dataHex, 'hex');
    const decipher = crypto.createDecipheriv(algorithm, key, iv);
    decipher.setAuthTag(tag);
    const dec = Buffer.concat([decipher.update(data), decipher.final()]);
    return dec.toString('utf8');
  }

  close(): void {
    for (const t of this.rotationTimers.values()) clearTimeout(t);
    this.rotationTimers.clear();
    if (this.db) {
      try {
        this.db.close();
      } catch {}
    }
  }
}
