import type { NextApiRequest, NextApiResponse } from 'next';
import { register } from '@/lib/monitoring/metrics';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
}
