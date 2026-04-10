import type { NextApiRequest, NextApiResponse } from 'next';
import { logViolation } from '../../../_store';
import { HOSViolation } from '@/types/hos.types';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'POST') {
    try {
      const violation = req.body as HOSViolation;
      const id = logViolation(violation);
      return res.status(201).json({ id });
    } catch (e: any) {
      return res.status(500).json({ message: e?.message || 'Failed to log violation' });
    }
  }
  return res.status(405).json({ message: 'Method not allowed' });
}
