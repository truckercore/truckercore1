import type { NextApiRequest, NextApiResponse } from 'next';
import { acceptLoad, jsonSafe } from '../../_store';
import { LoadAcceptanceRequest } from '@/types/load.types';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'POST') {
    try {
      const body = req.body as LoadAcceptanceRequest;
      if (!body?.loadId || !body?.driverId || !body?.acceptedAt) {
        return res.status(400).json({ message: 'Missing required fields' });
      }
      const load = acceptLoad({ ...body, acceptedAt: new Date(body.acceptedAt) });
      if (!load) return res.status(404).json({ message: 'Load not found' });
      return res.status(200).json(jsonSafe(load));
    } catch (e: any) {
      return res.status(500).json({ message: e?.message || 'Failed to accept load' });
    }
  }
  return res.status(405).json({ message: 'Method not allowed' });
}
