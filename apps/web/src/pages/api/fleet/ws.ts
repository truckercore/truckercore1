import type { NextApiRequest } from 'next';
import { Server as WebSocketServer, WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import { getRedisClient, getRedisSubscriber, REDIS_ENABLED } from '@/lib/redis/connection';
import logger from '@/lib/monitoring/logger';
import { wsConnectionsActive, wsMessagesTotal } from '@/lib/monitoring/metrics';

interface WebSocketWithMeta extends WebSocket {
  organizationId?: string;
  clientId?: string;
  isAlive?: boolean;
}

const wss = new WebSocketServer({ noServer: true });

// In-memory clients map (used when Redis is disabled)
const localClients = new Map<string, Set<WebSocketWithMeta>>();

// Redis pub/sub channels
const REDIS_CHANNEL_PREFIX = 'fleet:ws:';

// Initialize Redis adapter if enabled
let redisClient = REDIS_ENABLED ? getRedisClient() : null;
let redisSubscriber = REDIS_ENABLED ? getRedisSubscriber() : null;

if (REDIS_ENABLED && redisSubscriber) {
  // Subscribe to all organization channels
  redisSubscriber.psubscribe(`${REDIS_CHANNEL_PREFIX}*`, (err, count) => {
    if (err) {
      logger.error('Redis psubscribe error', { error: err });
    } else {
      logger.info(`Subscribed to ${count} Redis channels`);
    }
  });

  // Handle messages from Redis
  redisSubscriber.on('pmessage', (_pattern, channel, message) => {
    try {
      const orgId = channel.replace(REDIS_CHANNEL_PREFIX, '');
      const data = JSON.parse(message);

      // Broadcast to local clients for this organization
      broadcastToLocalClients(orgId, data);

      wsMessagesTotal.inc({ type: 'redis_received' });
    } catch (error) {
      logger.error('Error processing Redis message', { error, channel, message });
    }
  });
}

// WebSocket connection handler
wss.on('connection', (ws: WebSocketWithMeta, request: IncomingMessage) => {
  const url = new URL(request.url || '', `http://${request.headers.host}`);
  const orgId = url.searchParams.get('orgId');
  const clientId = generateClientId();

  if (!orgId) {
    ws.close(1008, 'Organization ID required');
    return;
  }

  ws.organizationId = orgId;
  ws.clientId = clientId;
  ws.isAlive = true;

  // Add to local clients
  if (!localClients.has(orgId)) {
    localClients.set(orgId, new Set());
  }
  localClients.get(orgId)!.add(ws);

  wsConnectionsActive.inc();
  logger.info('WebSocket client connected', {
    orgId,
    clientId,
    totalConnections: getTotalConnections(),
  });

  // Send welcome message
  ws.send(
    JSON.stringify({
      type: 'CONNECTED',
      data: { clientId, serverId: process.env.SERVER_ID || 'unknown' },
      timestamp: new Date().toISOString(),
    })
  );

  // Handle messages from client
  ws.on('message', (data: Buffer) => {
    try {
      const message = JSON.parse(data.toString());
      handleClientMessage(ws, orgId, message);
      wsMessagesTotal.inc({ type: 'client_message' });
    } catch (error) {
      logger.error('Failed to parse WebSocket message', { error });
    }
  });

  // Handle pong (heartbeat)
  ws.on('pong', () => {
    ws.isAlive = true;
  });

  // Handle disconnection
  ws.on('close', () => {
    localClients.get(orgId)?.delete(ws);
    if (localClients.get(orgId)?.size === 0) {
      localClients.delete(orgId);
    }

    wsConnectionsActive.dec();
    logger.info('WebSocket client disconnected', {
      orgId,
      clientId,
      totalConnections: getTotalConnections(),
    });
  });

  ws.on('error', (error) => {
    logger.error('WebSocket error', { orgId, clientId, error });
  });
});

// Heartbeat interval
const HEARTBEAT_MS = parseInt(process.env.WEBSOCKET_HEARTBEAT_INTERVAL || '30000', 10);
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws: WebSocketWithMeta) => {
    if (!ws.isAlive) {
      logger.warn('Client heartbeat timeout', {
        orgId: ws.organizationId,
        clientId: ws.clientId,
      });
      return ws.terminate();
    }

    ws.isAlive = false;
    try {
      ws.ping();
    } catch (e) {
      logger.error('Ping failed', { error: e });
    }
  });
}, HEARTBEAT_MS);

// Cleanup on server shutdown
wss.on('close', () => {
  clearInterval(heartbeatInterval);
});

// Handle client messages
function handleClientMessage(ws: WebSocketWithMeta, orgId: string, message: any) {
  switch (message.type) {
    case 'AUTH':
      logger.info('Client authenticated', { orgId, clientId: ws.clientId });
      ws.send(
        JSON.stringify({ type: 'AUTH_SUCCESS', timestamp: new Date().toISOString() })
      );
      break;

    case 'PING':
      ws.send(JSON.stringify({ type: 'PONG', timestamp: new Date().toISOString() }));
      break;

    case 'SUBSCRIBE_VEHICLES':
      // Store subscription preferences if needed
      logger.info('Client subscribed to vehicles', {
        orgId,
        clientId: ws.clientId,
        vehicleIds: message.data?.vehicleIds,
      });
      break;

    case 'UNSUBSCRIBE_VEHICLES':
      logger.info('Client unsubscribed from vehicles', { orgId, clientId: ws.clientId });
      break;

    default:
      logger.warn('Unknown message type', { type: message.type });
  }
}

// Broadcast to organization (with Redis support)
export async function broadcastToOrganization(orgId: string, message: any): Promise<void> {
  const messageStr = JSON.stringify({
    ...message,
    timestamp: new Date().toISOString(),
  });

  if (REDIS_ENABLED && redisClient) {
    // Publish to Redis - will be received by all server instances
    try {
      await redisClient.publish(`${REDIS_CHANNEL_PREFIX}${orgId}`, messageStr);
      wsMessagesTotal.inc({ type: 'redis_published' });
      // Use debug level to reduce noise if logger supports it
      try {
        (logger as any).debug?.('Message published to Redis', { orgId, type: message.type });
      } catch {}
    } catch (error) {
      logger.error('Failed to publish to Redis', { error, orgId });
      // Fallback to local broadcast
      broadcastToLocalClients(orgId, message);
    }
  } else {
    // Direct local broadcast when Redis is disabled
    broadcastToLocalClients(orgId, message);
  }
}

// Broadcast to local clients only
function broadcastToLocalClients(orgId: string, message: any): void {
  const orgClients = localClients.get(orgId);
  if (!orgClients || orgClients.size === 0) {
    try {
      (logger as any).debug?.('No local clients for organization', { orgId });
    } catch {}
    return;
  }

  const messageStr =
    typeof message === 'string'
      ? message
      : JSON.stringify({
          ...message,
          timestamp: new Date().toISOString(),
        });

  let sentCount = 0;
  orgClients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      try {
        client.send(messageStr);
        sentCount++;
        wsMessagesTotal.inc({ type: 'broadcast' });
      } catch (error) {
        logger.error('Failed to send message to client', {
          error,
          clientId: client.clientId,
        });
      }
    }
  });

  try {
    (logger as any).debug?.('Broadcast to local clients', {
      orgId,
      messageType: typeof message === 'object' ? message.type : 'unknown',
      sentCount,
      totalClients: orgClients.size,
    });
  } catch {}
}

// Broadcast to specific client
export function broadcastToClient(clientId: string, message: any): void {
  wss.clients.forEach((ws: WebSocketWithMeta) => {
    if (ws.clientId === clientId && ws.readyState === WebSocket.OPEN) {
      ws.send(
        JSON.stringify({
          ...message,
          timestamp: new Date().toISOString(),
        })
      );
      wsMessagesTotal.inc({ type: 'direct_message' });
    }
  });
}

// Helper functions
function generateClientId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function getTotalConnections(): number {
  return wss.clients.size;
}

// Get connection stats
export function getWebSocketStats() {
  const stats = {
    totalConnections: getTotalConnections(),
    organizations: localClients.size,
    redisEnabled: REDIS_ENABLED,
    serverId: process.env.SERVER_ID || 'unknown',
  };

  return stats;
}

// API handler
export default function handler(req: NextApiRequest, res: any) {
  if (req.method === 'GET') {
    if (res.socket.server.wss) {
      try {
        (logger as any).debug?.('WebSocket server already running');
      } catch {}
    } else {
      logger.info('Starting WebSocket server', {
        redisEnabled: REDIS_ENABLED,
        serverId: process.env.SERVER_ID,
      });
      res.socket.server.wss = wss;

      res.socket.server.on('upgrade', (request: IncomingMessage, socket: any, head: Buffer) => {
        if (request.url?.startsWith('/api/fleet/ws')) {
          wss.handleUpgrade(request, socket, head, (ws) => {
            wss.emit('connection', ws, request);
          });
        } else {
          socket.destroy();
        }
      });
    }
    res.end();
  } else if (req.method === 'POST') {
    // Allow manual broadcast via HTTP (for testing)
    const { orgId, message } = req.body || {};

    if (!orgId || !message) {
      return res.status(400).json({ error: 'orgId and message required' });
    }

    broadcastToOrganization(orgId, message);
    res.status(200).json({ success: true, message: 'Broadcast sent' });
  } else {
    res.setHeader('Allow', ['GET', 'POST']);
    res.status(405).json({ error: `Method ${req.method} Not Allowed` });
  }
}

// Export for server stats endpoint
export { wss, localClients };
