import type { NextApiRequest, NextApiResponse } from 'next';
import { addLocationsBatch } from '../../_store';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'POST') {
    try {
      const { locations } = req.body as { locations: any[] };
      if (!Array.isArray(locations)) return res.status(400).json({ message: 'locations must be an array' });
      addLocationsBatch(locations);
      return res.status(200).json({ synced: locations.length, failed: 0 });
    } catch (e: any) {
      return res.status(500).json({ message: e?.message || 'Failed to sync locations' });
    }
  }
  return res.status(405).json({ message: 'Method not allowed' });
}
