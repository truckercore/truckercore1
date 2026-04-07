export const FLEET_CONFIG = {
  wsUrl: process.env.NEXT_PUBLIC_WS_URL || (typeof window !== 'undefined' ? `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}` : 'ws://localhost:3000'),
  wsHeartbeatInterval: 15000,
  wsReconnectAttempts: 8,
  wsReconnectDelay: 1000,
  geofenceCheckInterval: 5000,
};

const apiBase = '';
export const API_ENDPOINTS = {
  vehicles: `${apiBase}/api/fleet/vehicles`,
  drivers: `${apiBase}/api/fleet/drivers`,
  loads: `${apiBase}/api/fleet/loads`,
  alerts: `${apiBase}/api/fleet/alerts`,
  geofences: `${apiBase}/api/fleet/geofences`,
  maintenance: `${apiBase}/api/fleet/maintenance`,
  analytics: `${apiBase}/api/fleet/analytics`,
  ws: `${apiBase}/api/fleet/ws`,
};
