import type { NextApiRequest, NextApiResponse } from 'next';
import { getWebSocketStats } from './ws';
import { checkRedisHealth, REDIS_ENABLED } from '@/lib/redis/connection';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const wsStats = getWebSocketStats();
    const redisHealth = REDIS_ENABLED ? await checkRedisHealth() : null;

    return res.status(200).json({
      websocket: wsStats,
      redis: redisHealth,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    return res.status(500).json({
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}
