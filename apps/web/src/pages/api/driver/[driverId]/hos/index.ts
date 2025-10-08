import type { NextApiRequest, NextApiResponse } from 'next';
import { getHOSState, jsonSafe } from '../../../_store';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { driverId } = req.query as { driverId: string };

  if (req.method === 'GET') {
    const state = getHOSState(driverId);
    return res.status(200).json(jsonSafe({ entries: state.entries, currentStatus: state.currentStatus }));
  }

  return res.status(405).json({ message: 'Method not allowed' });
}
