import type { NextApiRequest, NextApiResponse } from 'next';
import { getAvailableLoads, jsonSafe } from '../../../_store';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { driverId } = req.query as { driverId: string };
  if (req.method === 'GET') {
    const loads = getAvailableLoads();
    return res.status(200).json(jsonSafe(loads));
  }
  return res.status(405).json({ message: 'Method not allowed' });
}
