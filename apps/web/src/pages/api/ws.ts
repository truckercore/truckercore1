import type { NextApiRequest, NextApiResponse } from 'next';
import { initializeWebSocketServer } from '@/server/websocket-server';

export const config = {
  api: {
    bodyParser: false,
  },
};

export default function handler(_req: NextApiRequest, res: NextApiResponse) {
  initializeWebSocketServer(res, '/api/ws');
  res.end('WebSocket server is running');
}
