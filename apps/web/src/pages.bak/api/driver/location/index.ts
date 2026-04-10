import type { NextApiRequest, NextApiResponse } from 'next';
import { addLocation } from '../../_store';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'POST') {
    try {
      const body = req.body;
      addLocation(body);
      return res.status(200).json({ success: true });
    } catch (e: any) {
      return res.status(500).json({ success: false, message: e?.message || 'Failed to record location' });
    }
  }
  return res.status(405).json({ message: 'Method not allowed' });
}
