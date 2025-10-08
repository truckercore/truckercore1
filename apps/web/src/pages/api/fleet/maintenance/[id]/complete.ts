import type { NextApiRequest, NextApiResponse } from 'next';
import type { ApiResponse } from '@/types/fleet';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>
) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ success: false, error: `Method ${req.method} Not Allowed` });
  }

  const { id } = req.query as { id?: string };
  const { cost, notes, parts } = req.body || {};

  if (!id) {
    return res.status(400).json({ success: false, error: 'Maintenance record ID is required' });
  }

  try {
    if (USE_MOCK_DATA) {
      const updatedRecord = {
        id,
        status: 'completed',
        completedDate: new Date(),
        cost,
        notes,
        parts,
        updatedAt: new Date(),
      };
      return res.status(200).json({
        success: true,
        data: updatedRecord,
        message: 'Maintenance completed successfully',
      });
    }
    // TODO: Database update transaction
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Complete maintenance error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}
