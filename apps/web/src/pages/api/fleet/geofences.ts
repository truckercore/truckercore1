import type { NextApiRequest, NextApiResponse } from 'next';
import type { Geofence, ApiResponse } from '@/types/fleet';
import { generateMockGeofences } from '@/lib/fleet/mockData';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<Geofence | Geofence[]>>
) {
  const { method, query } = req;
  const { orgId, id } = query as { orgId?: string; id?: string };

  try {
    switch (method) {
      case 'GET':
        if (id) {
          return handleGetGeofence(req, res, id);
        }
        return handleGetGeofences(req, res, orgId || '');
      case 'POST':
        return handleCreateGeofence(req, res);
      case 'PUT':
        return handleUpdateGeofence(req, res);
      case 'DELETE':
        return handleDeleteGeofence(req, res);
      default:
        res.setHeader('Allow', ['GET', 'POST', 'PUT', 'DELETE']);
        return res.status(405).json({ success: false, error: `Method ${method} Not Allowed` });
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Geofences API error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}

async function handleGetGeofences(
  _req: NextApiRequest,
  res: NextApiResponse,
  _orgId: string
) {
  if (USE_MOCK_DATA) {
    const geofences = generateMockGeofences(5);
    return res.status(200).json({ success: true, data: geofences });
  }
  // TODO: Database query with PostGIS
}

async function handleGetGeofence(
  _req: NextApiRequest,
  res: NextApiResponse,
  id: string
) {
  if (USE_MOCK_DATA) {
    const geofences = generateMockGeofences(5);
    const geofence = geofences.find((g) => g.id === id);
    if (!geofence) {
      return res.status(404).json({ success: false, error: 'Geofence not found' });
    }
    return res.status(200).json({ success: true, data: geofence });
  }
  // TODO: Database query
}

async function handleCreateGeofence(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const geofenceData = req.body as Partial<Geofence>;
  if (!geofenceData.name || !geofenceData.coordinates || !geofenceData.organizationId) {
    return res
      .status(400)
      .json({ success: false, error: 'Missing required fields: name, coordinates, organizationId' });
  }
  if (USE_MOCK_DATA) {
    const newGeofence: Geofence = {
      id: crypto.randomUUID(),
      organizationId: geofenceData.organizationId!,
      name: geofenceData.name!,
      type: (geofenceData.type as any) || 'allowed',
      description: geofenceData.description,
      coordinates: geofenceData.coordinates as any,
      radius: geofenceData.radius,
      center: geofenceData.center as any,
      active: geofenceData.active ?? true,
      alertOnEntry: geofenceData.alertOnEntry ?? true,
      alertOnExit: geofenceData.alertOnExit ?? true,
      allowedVehicleIds: geofenceData.allowedVehicleIds,
      restrictedVehicleIds: geofenceData.restrictedVehicleIds,
      schedule: geofenceData.schedule,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    return res
      .status(201)
      .json({ success: true, data: newGeofence, message: 'Geofence created successfully' });
  }
  // TODO: Database insert with PostGIS
}

async function handleUpdateGeofence(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id, ...updates } = req.body || {};
  if (!id) {
    return res.status(400).json({ success: false, error: 'Geofence ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({
      success: true,
      data: { id, ...updates, updatedAt: new Date() },
      message: 'Geofence updated successfully',
    });
  }
  // TODO: Database update
}

async function handleDeleteGeofence(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id } = req.query as { id?: string };
  if (!id) {
    return res.status(400).json({ success: false, error: 'Geofence ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({ success: true, message: 'Geofence deleted successfully' });
  }
  // TODO: Database delete
}
