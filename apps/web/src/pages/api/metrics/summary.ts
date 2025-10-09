import type { NextApiRequest, NextApiResponse } from 'next';
import { apiResponse, requireAuth, APIException } from '@/lib/api/middleware';
import { apiMonitoring } from '@/lib/monitoring/api-metrics';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    const auth = await requireAuth(req as any);
    if ((auth as any).role !== 'admin') {
      throw new APIException(403, 'FORBIDDEN', 'Admin access required');
    }

    const timeWindow = parseInt((req.query.timeWindow as string) || '3600000', 10);
    const summary = apiMonitoring.getSummary(timeWindow);

    res.status(200).json(summary);
  } catch (error: any) {
    res.status(error.statusCode || 500).json({
      error: {
        code: error.code || 'INTERNAL_ERROR',
        message: error.message || 'Internal Server Error',
      },
    });
  }
}
