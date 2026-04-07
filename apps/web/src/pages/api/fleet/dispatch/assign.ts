import type { NextApiRequest, NextApiResponse } from 'next';
import type { ApiResponse } from '@/types/fleet';
import { broadcastToOrganization } from '../ws';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>
) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ success: false, error: `Method ${req.method} Not Allowed` });
  }

  const { loadId, vehicleId, driverId, organizationId } = req.body || {};

  if (!loadId || !vehicleId || !driverId) {
    return res
      .status(400)
      .json({ success: false, error: 'Missing required fields: loadId, vehicleId, driverId' });
  }

  try {
    if (USE_MOCK_DATA) {
      await new Promise((r) => setTimeout(r, 500));

      const assignment = {
        loadId,
        vehicleId,
        driverId,
        assignedAt: new Date(),
        status: 'assigned',
      };

      if (organizationId) {
        try {
          broadcastToOrganization(organizationId, {
            type: 'LOAD_STATUS_UPDATE',
            data: {
              id: loadId,
              status: 'assigned',
              assignedVehicleId: vehicleId,
              assignedDriverId: driverId,
            },
          });
          broadcastToOrganization(organizationId, {
            type: 'VEHICLE_UPDATE',
            data: { id: vehicleId, status: 'active' },
          });
          broadcastToOrganization(organizationId, {
            type: 'DRIVER_STATUS_UPDATE',
            data: { id: driverId, status: 'on-route' },
          });
        } catch (e) {
          // Swallow ws errors in mock
        }
      }

      return res
        .status(200)
        .json({ success: true, data: assignment, message: 'Load assigned successfully' });
    }

    // TODO: Real DB transaction encapsulating updates and then broadcasting
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Dispatch assignment error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}
