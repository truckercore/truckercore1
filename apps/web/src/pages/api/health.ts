import type { NextApiRequest, NextApiResponse } from 'next';
import { checkRedisHealth, REDIS_ENABLED } from '@/lib/redis/connection';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Check Redis if enabled
    const redisStatus = REDIS_ENABLED ? await checkRedisHealth() : ({
      connected: false,
      disabled: true,
    } as any);

    // Check WebSocket server (presence implies running)
    const wsStatus = {
      running: true,
    };

    const healthy = !REDIS_ENABLED || redisStatus.connected;

    return res.status(healthy ? 200 : 503).json({
      status: healthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version,
      checks: {
        redis: redisStatus,
        websocket: wsStatus,
      },
      features: {
        redisEnabled: REDIS_ENABLED,
      },
    });
  } catch (error: any) {
    return res.status(503).json({
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}
