import type { NextApiRequest, NextApiResponse } from 'next';
import { getActiveLoad, jsonSafe } from '../../_store';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { driverId } = req.query as { driverId: string };
  if (req.method === 'GET') {
    const load = getActiveLoad(driverId);
    return res.status(200).json(jsonSafe(load));
  }
  return res.status(405).json({ message: 'Method not allowed' });
}
