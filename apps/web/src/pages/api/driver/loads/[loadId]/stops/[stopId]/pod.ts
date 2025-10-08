import type { NextApiRequest, NextApiResponse } from 'next';
import { submitPOD, jsonSafe } from '../../../../../_store';
import { ProofOfDelivery } from '@/types/load.types';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { loadId, stopId } = req.query as { loadId: string; stopId: string };

  if (req.method === 'POST') {
    try {
      const pod = req.body as ProofOfDelivery;
      if (!pod || !pod.id || !pod.stopId) {
        return res.status(400).json({ message: 'Invalid POD payload' });
      }
      const saved = submitPOD(loadId, stopId, pod);
      if (!saved) return res.status(404).json({ message: 'Load or stop not found' });
      return res.status(201).json(jsonSafe(saved));
    } catch (e: any) {
      return res.status(500).json({ message: e?.message || 'Failed to submit POD' });
    }
  }

  return res.status(405).json({ message: 'Method not allowed' });
}
