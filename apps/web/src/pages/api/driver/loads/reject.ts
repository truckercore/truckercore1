import type { NextApiRequest, NextApiResponse } from 'next';
import { rejectLoad } from '../../_store';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'POST') {
    try {
      const { loadId, reason } = req.body as { loadId: string; reason?: string };
      if (!loadId) return res.status(400).json({ message: 'Missing loadId' });
      const ok = rejectLoad(loadId, reason);
      if (!ok) return res.status(404).json({ message: 'Load not found' });
      return res.status(200).json({ success: true });
    } catch (e: any) {
      return res.status(500).json({ message: e?.message || 'Failed to reject load' });
    }
  }
  return res.status(405).json({ message: 'Method not allowed' });
}
