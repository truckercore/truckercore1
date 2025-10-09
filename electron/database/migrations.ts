// electron/database/migrations.ts
// Database Migration System for Electron (better-sqlite3)
// Falls back to a no-op if better-sqlite3 is unavailable on the host.

// We intentionally require at runtime to keep better-sqlite3 truly optional.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let BetterSqlite3: any = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  BetterSqlite3 = require('better-sqlite3');
} catch (_e) {
  BetterSqlite3 = null;
}

export type DatabaseHandle = any;

interface Migration {
  version: number;
  name: string;
  up: (db: DatabaseHandle) => void;
  down: (db: DatabaseHandle) => void;
}

export class DatabaseMigrator {
  private db: DatabaseHandle | null = null;
  private dbPath: string;

  constructor(dbPath: string) {
    this.dbPath = dbPath;
    if (!BetterSqlite3) {
      // eslint-disable-next-line no-console
      console.warn('[DatabaseMigrator] better-sqlite3 not available; migrations are no-op.');
      return;
    }
    this.db = new BetterSqlite3(dbPath);
    this.initializeMigrationTable();
  }

  private get hasDb(): boolean {
    return !!this.db;
  }

  private initializeMigrationTable(): void {
    if (!this.hasDb) return;
    this.db!.exec(`
      CREATE TABLE IF NOT EXISTS migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at INTEGER NOT NULL
      );
    `);
  }

  getCurrentVersion(): number {
    if (!this.hasDb) return 0;
    const row = this.db!.prepare('SELECT MAX(version) as version FROM migrations').get() as { version?: number };
    return row?.version || 0;
  }

  async migrate(): Promise<void> {
    if (!this.hasDb) return; // no-op
    const current = this.getCurrentVersion();
    const migrations = this.getMigrations();
    const pending = migrations.filter((m) => m.version > current);
    if (pending.length === 0) {
      // eslint-disable-next-line no-console
      console.log('[Database] No pending migrations');
      return;
    }
    // eslint-disable-next-line no-console
    console.log(`[Database] Running ${pending.length} migration(s)...`);
    for (const m of pending) {
      try {
        // eslint-disable-next-line no-console
        console.log(`[Database] Applying migration ${m.version}: ${m.name}`);
        this.db!.transaction(() => {
          m.up(this.db!);
          this.db!.prepare('INSERT INTO migrations (version, name, applied_at) VALUES (?, ?, ?)').run(m.version, m.name, Date.now());
        })();
        // eslint-disable-next-line no-console
        console.log(`[Database] ✓ Migration ${m.version} applied`);
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error(`[Database] ✗ Migration ${m.version} failed:`, e);
        throw e;
      }
    }
  }

  async rollback(targetVersion?: number): Promise<void> {
    if (!this.hasDb) return; // no-op
    const current = this.getCurrentVersion();
    const migrations = this.getMigrations();
    const target = targetVersion !== undefined ? targetVersion : current - 1;
    if (target >= current) {
      // eslint-disable-next-line no-console
      console.log('[Database] No rollback needed');
      return;
    }
    const toRollback = migrations.filter((m) => m.version > target && m.version <= current).reverse();
    // eslint-disable-next-line no-console
    console.log(`[Database] Rolling back ${toRollback.length} migration(s)...`);
    for (const m of toRollback) {
      try {
        // eslint-disable-next-line no-console
        console.log(`[Database] Rolling back migration ${m.version}: ${m.name}`);
        this.db!.transaction(() => {
          m.down(this.db!);
          this.db!.prepare('DELETE FROM migrations WHERE version = ?').run(m.version);
        })();
        // eslint-disable-next-line no-console
        console.log(`[Database] ✓ Migration ${m.version} rolled back`);
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error(`[Database] ✗ Rollback ${m.version} failed:`, e);
        throw e;
      }
    }
  }

  private getMigrations(): Migration[] {
    const migrations: Migration[] = [
      {
        version: 1,
        name: 'initial_schema',
        up: (db) => {
          db.exec(`
            CREATE TABLE IF NOT EXISTS users (
              id TEXT PRIMARY KEY,
              email TEXT UNIQUE NOT NULL,
              name TEXT NOT NULL,
              role TEXT NOT NULL,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS fleet (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              status TEXT NOT NULL,
              created_at INTEGER NOT NULL
            );
          `);
        },
        down: (db) => {
          db.exec('DROP TABLE IF EXISTS users; DROP TABLE IF EXISTS fleet;');
        },
      },
      {
        version: 2,
        name: 'add_fleet_tracking',
        up: (db) => {
          db.exec(`
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
            CREATE INDEX IF NOT EXISTS idx_alerts_unack ON fleet_alerts(acknowledged, severity) WHERE acknowledged = 0;
          `);
        },
        down: (db) => db.exec('DROP TABLE IF EXISTS fleet_live; DROP TABLE IF EXISTS fleet_alerts;'),
      },
      {
        version: 3,
        name: 'add_owner_operator_tables',
        up: (db) => {
          db.exec(`
            CREATE TABLE IF NOT EXISTS expenses (
              id TEXT PRIMARY KEY,
              category TEXT NOT NULL,
              amount REAL NOT NULL,
              date TEXT NOT NULL,
              location TEXT,
              vendor TEXT,
              notes TEXT,
              receipt_path TEXT,
              tax_deductible BOOLEAN DEFAULT 1,
              mileage REAL,
              created_at INTEGER
            );
            CREATE TABLE IF NOT EXISTS loads (
              id TEXT PRIMARY KEY,
              load_number TEXT UNIQUE,
              broker TEXT,
              pickup TEXT,
              delivery TEXT,
              rate REAL,
              miles REAL,
              weight REAL,
              pickup_date TEXT,
              delivery_date TEXT,
              payment_status TEXT DEFAULT 'pending',
              payment_date TEXT,
              created_at INTEGER
            );
            CREATE TABLE IF NOT EXISTS maintenance_schedule (
              id TEXT PRIMARY KEY,
              type TEXT,
              due_date TEXT,
              due_miles INTEGER,
              current_miles INTEGER,
              last_completed TEXT,
              cost REAL,
              vendor TEXT,
              notes TEXT,
              completed BOOLEAN DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date DESC);
            CREATE INDEX IF NOT EXISTS idx_loads_status ON loads(payment_status);
          `);
        },
        down: (db) => db.exec('DROP TABLE IF EXISTS expenses; DROP TABLE IF EXISTS loads; DROP TABLE IF EXISTS maintenance_schedule;'),
      },
      {
        version: 4,
        name: 'add_freight_broker_tables',
        up: (db) => {
          db.exec(`
            CREATE TABLE IF NOT EXISTS load_postings (
              id TEXT PRIMARY KEY,
              customer TEXT,
              origin TEXT,
              origin_lat REAL,
              origin_lng REAL,
              destination TEXT,
              dest_lat REAL,
              dest_lng REAL,
              pickup_date TEXT,
              delivery_date TEXT,
              weight REAL,
              equipment TEXT,
              rate REAL,
              miles REAL,
              commodity TEXT,
              special_requirements TEXT,
              status TEXT DEFAULT 'open',
              assigned_carrier TEXT,
              posted_at INTEGER,
              covered_at INTEGER
            );
            CREATE TABLE IF NOT EXISTS carriers (
              id TEXT PRIMARY KEY,
              company_name TEXT,
              mc_number TEXT UNIQUE,
              dot_number TEXT,
              contact TEXT,
              phone TEXT,
              email TEXT,
              equipment TEXT,
              preferred_lanes TEXT,
              rating REAL DEFAULT 5.0,
              total_loads INTEGER DEFAULT 0,
              on_time_percentage REAL DEFAULT 100.0,
              insurance_liability REAL,
              insurance_cargo REAL,
              insurance_expiry TEXT,
              status TEXT DEFAULT 'active',
              created_at INTEGER
            );
            CREATE TABLE IF NOT EXISTS load_bids (
              id TEXT PRIMARY KEY,
              load_id TEXT,
              carrier_id TEXT,
              bid_amount REAL,
              notes TEXT,
              submitted_at INTEGER,
              status TEXT DEFAULT 'pending'
            );
            CREATE INDEX IF NOT EXISTS idx_loads_status2 ON load_postings(status);
            CREATE INDEX IF NOT EXISTS idx_bids_load ON load_bids(load_id, status);
          `);
        },
        down: (db) => db.exec('DROP TABLE IF EXISTS load_bids; DROP TABLE IF EXISTS carriers; DROP TABLE IF EXISTS load_postings;'),
      },
      {
        version: 5,
        name: 'add_truck_stop_tables',
        up: (db) => {
          db.exec(`
            CREATE TABLE IF NOT EXISTS truck_stops (
              id TEXT PRIMARY KEY,
              name TEXT,
              address TEXT,
              lat REAL,
              lng REAL,
              services TEXT,
              fuel_diesel REAL,
              fuel_def REAL,
              parking_total INTEGER,
              parking_available INTEGER,
              amenities TEXT,
              hours TEXT,
              rating REAL DEFAULT 4.5,
              review_count INTEGER DEFAULT 0,
              phone TEXT,
              website TEXT
            );
            CREATE TABLE IF NOT EXISTS reservations (
              id TEXT PRIMARY KEY,
              truck_stop_id TEXT,
              driver_id TEXT,
              driver_name TEXT,
              truck_number TEXT,
              service_type TEXT,
              check_in TEXT,
              check_out TEXT,
              status TEXT DEFAULT 'pending',
              amount REAL,
              notes TEXT,
              created_at INTEGER
            );
            CREATE TABLE IF NOT EXISTS loyalty_rewards (
              id TEXT PRIMARY KEY,
              driver_id TEXT,
              points INTEGER DEFAULT 0,
              tier TEXT DEFAULT 'bronze',
              total_spent REAL DEFAULT 0,
              last_visit INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status, check_in);
          `);
        },
        down: (db) => db.exec('DROP TABLE IF EXISTS reservations; DROP TABLE IF EXISTS loyalty_rewards; DROP TABLE IF EXISTS truck_stops;'),
      },
      {
        version: 6,
        name: 'add_performance_logs',
        up: (db) => {
          db.exec(`
            CREATE TABLE IF NOT EXISTS performance_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp INTEGER NOT NULL,
              cpu_usage REAL,
              memory_usage REAL,
              disk_usage REAL,
              network_latency INTEGER,
              active_windows INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_perf_timestamp ON performance_logs(timestamp DESC);
          `);
        },
        down: (db) => db.exec('DROP TABLE IF EXISTS performance_logs;'),
      },
      {
        version: 7,
        name: 'add_analytics_events',
        up: (db) => {
          db.exec(`
            CREATE TABLE IF NOT EXISTS analytics_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event_name TEXT NOT NULL,
              user_id TEXT,
              session_id TEXT,
              properties TEXT,
              timestamp INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_analytics_timestamp ON analytics_events(timestamp DESC);
            CREATE INDEX IF NOT EXISTS idx_analytics_event ON analytics_events(event_name);
          `);
        },
        down: (db) => db.exec('DROP TABLE IF EXISTS analytics_events;'),
      },
    ];
    return migrations;
  }

  close(): void {
    if (this.db) {
      this.db.close();
      this.db = null;
    }
  }
}

export async function runMigrations(dbPath: string): Promise<void> {
  const migrator = new DatabaseMigrator(dbPath);
  try {
    await migrator.migrate();
  } finally {
    migrator.close();
  }
}
