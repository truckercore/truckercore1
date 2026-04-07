#!/usr/bin/env node

import * as path from 'path';
import { runMigrations, DatabaseMigrator } from './migrations';

// CLI tool for running database migrations
// Usage:
//   npm run migrate           # Run all pending migrations
//   npm run migrate:status    # Check migration status
//   npm run migrate:rollback  # Rollback last migration
//   npm run migrate:rollback -- 3  # Rollback to version 3

async function main() {
  const command = process.argv[2] || 'migrate';
  const dbPath = path.join(process.cwd(), 'truckercore.db');

  // Try to import optional dependency; gracefully no-op when unavailable
  let sqliteAvailable = true;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    require('better-sqlite3');
  } catch {
    sqliteAvailable = false;
    console.warn('[migrate] better-sqlite3 not available; skipping migrations.');
  }

  try {
    switch (command) {
      case 'migrate':
      case 'up':
        if (sqliteAvailable) {
          await runMigrations(dbPath);
        }
        break;
      case 'status':
        if (sqliteAvailable) {
          const migrator = new DatabaseMigrator(dbPath);
          console.log(`Current database version: ${migrator.getCurrentVersion()}`);
          migrator.close();
        } else {
          console.log('Current database version: 0 (sqlite not available)');
        }
        break;
      case 'rollback':
      case 'down': {
        const targetVersion = process.argv[3] ? parseInt(process.argv[3], 10) : undefined;
        if (sqliteAvailable) {
          const migrator = new DatabaseMigrator(dbPath);
          await migrator.rollback(targetVersion);
          migrator.close();
        }
        break;
      }
      default:
        console.error(`Unknown command: ${command}`);
        console.log('Available commands: migrate, status, rollback');
        process.exitCode = 1;
    }
  } catch (error) {
    console.error('Migration failed:', error);
    process.exitCode = 1;
  }
}

void main();
