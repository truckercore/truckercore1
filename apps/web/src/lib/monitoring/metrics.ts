import { register, Counter, Histogram, Gauge } from 'prom-client';

// HTTP request metrics
export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
});

export const httpRequestTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

// WebSocket metrics
export const wsConnectionsActive = new Gauge({
  name: 'ws_connections_active',
  help: 'Number of active WebSocket connections',
});

export const wsMessagesTotal = new Counter({
  name: 'ws_messages_total',
  help: 'Total number of WebSocket messages',
  labelNames: ['type'],
});

// Database metrics
export const dbQueryDuration = new Histogram({
  name: 'db_query_duration_seconds',
  help: 'Duration of database queries in seconds',
  labelNames: ['operation'],
});

export const dbConnectionsActive = new Gauge({
  name: 'db_connections_active',
  help: 'Number of active database connections',
});

// Fleet metrics
export const vehiclesActive = new Gauge({
  name: 'fleet_vehicles_active',
  help: 'Number of active vehicles',
});

export const alertsGenerated = new Counter({
  name: 'fleet_alerts_generated_total',
  help: 'Total number of alerts generated',
  labelNames: ['type', 'severity'],
});

export { register };
