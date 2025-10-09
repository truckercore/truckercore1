import { Server } from 'socket.io';
import type { NextApiResponse } from 'next';
import { createServer } from 'http';

let io: Server | null = null;

export function initializeWebSocketServer(res: NextApiResponse, path: string = '/api/ws') {
  // In Next.js API Routes, we attach the Server instance to the HTTP server on first call
  // to enable reuse across requests.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const anyRes = res as any;
  if (anyRes.socket.server.io) {
    io = anyRes.socket.server.io as Server;
    return io;
  }

  const httpServer = anyRes.socket.server as ReturnType<typeof createServer>;
  io = new Server(httpServer, {
    cors: {
      origin: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
      methods: ['GET', 'POST'],
    },
    path,
  });

  anyRes.socket.server.io = io;

  io.on('connection', (socket) => {
    // Authentication
    socket.on('authenticate', async (token: string) => {
      try {
        const user = await verifyToken(token);
        (socket.data as any).userId = user.userId;
        (socket.data as any).role = user.role;
        socket.join(`user:${user.userId}`);
        if (user.role === 'driver') socket.join('drivers');
        if (user.role === 'dispatcher') socket.join('dispatchers');
        socket.emit('authenticated', { userId: user.userId });
      } catch (err) {
        socket.emit('auth_error', { message: 'Authentication failed' });
        socket.disconnect();
      }
    });

    socket.on('subscribe', (channel: string) => {
      if ((socket.data as any).userId) socket.join(channel);
    });
    socket.on('unsubscribe', (channel: string) => socket.leave(channel));
  });

  return io;
}

export function getWebSocketServer(): Server {
  if (!io) {
    throw new Error('WebSocket server not initialized');
  }
  return io;
}

async function verifyToken(token: string): Promise<{ userId: string; role: string }> {
  // TODO: Replace with real JWT verification
  try {
    const decoded = JSON.parse(Buffer.from(token, 'base64').toString());
    return decoded;
  } catch {
    throw new Error('Invalid token');
  }
}
