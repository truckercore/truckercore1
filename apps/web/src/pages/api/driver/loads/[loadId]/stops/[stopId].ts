import type { NextApiRequest, NextApiResponse } from 'next';
import { updateStopStatus, jsonSafe } from '../../../../_store';
import { LoadStop } from '@/types/load.types';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { loadId, stopId } = req.query as { loadId: string; stopId: string };

  if (req.method === 'PATCH') {
    try {
      const { status, timestamp } = req.body as { status: LoadStop['status']; timestamp?: string | Date };
      if (!status) return res.status(400).json({ message: 'Missing status' });
      const ts = timestamp ? new Date(timestamp) : new Date();
      const load = updateStopStatus(loadId, stopId, status, ts);
      if (!load) return res.status(404).json({ message: 'Load or stop not found' });
      return res.status(200).json(jsonSafe(load));
    } catch (e: any) {
      return res.status(500).json({ message: e?.message || 'Failed to update stop status' });
    }
  }

  return res.status(405).json({ message: 'Method not allowed' });
}
