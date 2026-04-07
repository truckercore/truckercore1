import type { NextApiRequest, NextApiResponse } from 'next';
import { getHOSState, setHOSState, jsonSafe } from '../../../_store';
import { HOSEntry, HOSStatus } from '@/types/hos.types';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { driverId } = req.query as { driverId: string };

  if (req.method === 'POST') {
    try {
      const { status, location, timestamp } = req.body as { status: HOSStatus; location?: { latitude: number; longitude: number }; timestamp?: string | Date };
      if (!status) return res.status(400).json({ message: 'Missing status' });
      const state = getHOSState(driverId);

      // Close previous open entry
      const open = [...state.entries].reverse().find((e) => !e.endTime);
      const now = timestamp ? new Date(timestamp) : new Date();
      if (open) {
        open.endTime = now;
        open.updatedAt = new Date();
      }

      const entry: HOSEntry = {
        id: `hos-${driverId}-${Date.now()}`,
        driverId,
        status,
        startTime: now,
        location: {
          latitude: location?.latitude ?? 0,
          longitude: location?.longitude ?? 0,
        },
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      state.entries.push(entry);
      state.currentStatus = status;
      setHOSState(driverId, state);

      return res.status(201).json(jsonSafe(entry));
    } catch (e: any) {
      return res.status(500).json({ message: e?.message || 'Failed to change status' });
    }
  }

  return res.status(405).json({ message: 'Method not allowed' });
}
