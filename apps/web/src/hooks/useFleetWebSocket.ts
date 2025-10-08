import { useEffect, useRef, useState, useCallback } from 'react';
import { FLEET_CONFIG } from '../lib/fleet/config';
import { useFleetStore } from '../stores/fleetStore';

// Fallback type if not present in types/fleet
export type WebSocketMessage = {
  type: string;
  data?: any;
  error?: string;
  timestamp?: string;
};

export function useFleetWebSocket(organizationId: string) {
  const [isConnected, setIsConnected] = useState(false);
  const [lastMessage, setLastMessage] = useState<WebSocketMessage | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reconnectAttemptsRef = useRef(0);
  const heartbeatIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const store = useFleetStore();

  const connect = useCallback(() => {
    if (wsRef.current) {
      try { wsRef.current.close(); } catch (_) {}
      wsRef.current = null;
    }

    try {
      const wsUrl = `${FLEET_CONFIG.wsUrl}/api/fleet/ws?orgId=${organizationId}`;
      // eslint-disable-next-line no-console
      console.log(`[WS] Connecting to ${wsUrl}`);
      const ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        setIsConnected(true);
        store.setWebSocketConnected?.(true);
        reconnectAttemptsRef.current = 0;
        // auth
        ws.send(JSON.stringify({ type: 'AUTH', data: { organizationId } }));
        // heartbeat
        heartbeatIntervalRef.current = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ type: 'PING' }));
        }, FLEET_CONFIG.wsHeartbeatInterval);
      };

      ws.onmessage = (event) => {
        try {
          const msg: WebSocketMessage = JSON.parse(event.data);
          if (msg.type === 'PONG' || msg.type === 'AUTH_SUCCESS') return;
          if (msg.type === 'ERROR') {
            // eslint-disable-next-line no-console
            console.error('[WS] Error message:', msg.error);
            return;
          }
          setLastMessage(msg);
        } catch (e) {
          // eslint-disable-next-line no-console
          console.error('[WS] Failed to parse message', e);
        }
      };

      ws.onerror = (e) => {
        // eslint-disable-next-line no-console
        console.error('[WS] error', e);
      };

      ws.onclose = (ev) => {
        setIsConnected(false);
        store.setWebSocketConnected?.(false);
        wsRef.current = null;
        if (heartbeatIntervalRef.current) { clearInterval(heartbeatIntervalRef.current); heartbeatIntervalRef.current = null; }
        if (reconnectAttemptsRef.current < FLEET_CONFIG.wsReconnectAttempts) {
          const delay = FLEET_CONFIG.wsReconnectDelay * Math.pow(2, reconnectAttemptsRef.current);
          reconnectAttemptsRef.current++;
          // eslint-disable-next-line no-console
          console.log(`[WS] Reconnecting in ${delay}ms (attempt ${reconnectAttemptsRef.current})`);
          reconnectTimeoutRef.current = setTimeout(() => connect(), delay);
        } else {
          // eslint-disable-next-line no-console
          console.error('[WS] Max reconnection attempts reached');
        }
      };

      wsRef.current = ws;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('[WS] Failed to create connection', e);
      setIsConnected(false);
      store.setWebSocketConnected?.(false);
    }
  }, [organizationId, store]);

  useEffect(() => {
    connect();
    return () => {
      if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);
      if (heartbeatIntervalRef.current) clearInterval(heartbeatIntervalRef.current);
      if (wsRef.current) try { wsRef.current.close(); } catch (_) {}
    };
  }, [connect]);

  const sendMessage = useCallback((message: Omit<WebSocketMessage, 'timestamp'>) => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ ...message, timestamp: new Date().toISOString() }));
    } else {
      // eslint-disable-next-line no-console
      console.warn('[WS] Not connected; message not sent', message);
    }
  }, []);

  const subscribeToVehicles = useCallback((vehicleIds: string[]) => {
    sendMessage({ type: 'SUBSCRIBE_VEHICLES', data: { vehicleIds } });
  }, [sendMessage]);

  const unsubscribeFromVehicles = useCallback((vehicleIds: string[]) => {
    sendMessage({ type: 'UNSUBSCRIBE_VEHICLES', data: { vehicleIds } });
  }, [sendMessage]);

  return { isConnected, lastMessage, sendMessage, subscribeToVehicles, unsubscribeFromVehicles, reconnect: connect } as const;
}
