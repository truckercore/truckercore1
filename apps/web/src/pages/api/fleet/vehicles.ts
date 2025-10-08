import type { NextApiRequest, NextApiResponse } from 'next';
import type { Vehicle, ApiResponse } from '@/types/fleet';
import { generateMockVehicles } from '@/lib/fleet/mockData';

// In production, replace with actual database queries
const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<Vehicle | Vehicle[]>>
) {
  const { method, query } = req;
  const { orgId, id, status } = query as { orgId?: string; id?: string; status?: string };

  // Validate organization ID for mutating methods
  if (!orgId && method !== 'GET') {
    return res.status(400).json({ success: false, error: 'Organization ID is required' });
  }

  try {
    switch (method) {
      case 'GET':
        if (id) {
          return handleGetVehicle(req, res, id);
        }
        return handleGetVehicles(req, res, orgId || '', status);
      case 'POST':
        return handleCreateVehicle(req, res);
      case 'PUT':
        return handleUpdateVehicle(req, res);
      case 'DELETE':
        return handleDeleteVehicle(req, res);
      default:
        res.setHeader('Allow', ['GET', 'POST', 'PUT', 'DELETE']);
        return res.status(405).json({ success: false, error: `Method ${method} Not Allowed` });
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Vehicles API error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}

async function handleGetVehicles(
  _req: NextApiRequest,
  res: NextApiResponse,
  _orgId: string,
  status?: string
) {
  if (USE_MOCK_DATA) {
    let vehicles = generateMockVehicles(10);
    if (status) {
      const statuses = status.split(',');
      vehicles = vehicles.filter((v) => statuses.includes(v.status));
    }
    return res.status(200).json({ success: true, data: vehicles });
  }
  // TODO: Database query
}

async function handleGetVehicle(
  _req: NextApiRequest,
  res: NextApiResponse,
  id: string
) {
  if (USE_MOCK_DATA) {
    const vehicles = generateMockVehicles(10);
    const vehicle = vehicles.find((v) => v.id === id);
    if (!vehicle) {
      return res.status(404).json({ success: false, error: 'Vehicle not found' });
    }
    return res.status(200).json({ success: true, data: vehicle });
  }
  // TODO: Database query
}

async function handleCreateVehicle(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const vehicleData = req.body as Partial<Vehicle>;

  if (!vehicleData.name || !vehicleData.type || !vehicleData.organizationId) {
    return res
      .status(400)
      .json({ success: false, error: 'Missing required fields: name, type, organizationId' });
  }

  if (USE_MOCK_DATA) {
    const newVehicle: Vehicle = {
      id: crypto.randomUUID(),
      organizationId: vehicleData.organizationId,
      name: vehicleData.name!,
      type: vehicleData.type!,
      status: (vehicleData.status as any) || 'idle',
      location:
        vehicleData.location ||
        ({ lat: 39.8283, lng: -98.5795, heading: 0, speed: 0, timestamp: new Date() } as any),
      fuel: vehicleData.fuel ?? 100,
      odometer: vehicleData.odometer ?? 0,
      vin: vehicleData.vin,
      make: vehicleData.make,
      model: vehicleData.model,
      year: vehicleData.year,
      licensePlate: vehicleData.licensePlate,
      capacity: vehicleData.capacity as any,
      createdAt: new Date(),
      updatedAt: new Date(),
      lastUpdate: new Date(),
      driver: vehicleData.driver,
      currentRoute: vehicleData.currentRoute,
    } as Vehicle;

    return res
      .status(201)
      .json({ success: true, data: newVehicle, message: 'Vehicle created successfully' });
  }
  // TODO: Database insert
}

async function handleUpdateVehicle(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id, ...updates } = req.body || {};
  if (!id) {
    return res.status(400).json({ success: false, error: 'Vehicle ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({
      success: true,
      data: { id, ...updates, updatedAt: new Date() },
      message: 'Vehicle updated successfully',
    });
  }
  // TODO: Database update
}

async function handleDeleteVehicle(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id } = req.query as { id?: string };
  if (!id) {
    return res.status(400).json({ success: false, error: 'Vehicle ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({ success: true, message: 'Vehicle deleted successfully' });
  }
  // TODO: Database delete
}
