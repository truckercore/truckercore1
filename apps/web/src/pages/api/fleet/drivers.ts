import type { NextApiRequest, NextApiResponse } from 'next';
import type { Driver, ApiResponse } from '@/types/fleet';
import { generateMockDrivers } from '@/lib/fleet/mockData';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<Driver | Driver[]>>
) {
  const { method, query } = req;
  const { orgId, id, status } = query as { orgId?: string; id?: string; status?: string };

  try {
    switch (method) {
      case 'GET':
        if (id) {
          return handleGetDriver(req, res, id);
        }
        return handleGetDrivers(req, res, orgId || '', status);
      case 'POST':
        return handleCreateDriver(req, res);
      case 'PUT':
        return handleUpdateDriver(req, res);
      case 'DELETE':
        return handleDeleteDriver(req, res);
      default:
        res.setHeader('Allow', ['GET', 'POST', 'PUT', 'DELETE']);
        return res.status(405).json({ success: false, error: `Method ${method} Not Allowed` });
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Drivers API error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}

async function handleGetDrivers(
  _req: NextApiRequest,
  res: NextApiResponse,
  _orgId: string,
  status?: string
) {
  if (USE_MOCK_DATA) {
    let drivers = generateMockDrivers(15);
    if (status) {
      const statuses = status.split(',');
      drivers = drivers.filter((d) => statuses.includes(d.status));
    }
    return res.status(200).json({ success: true, data: drivers });
  }
  // TODO: Database query
}

async function handleGetDriver(
  _req: NextApiRequest,
  res: NextApiResponse,
  id: string
) {
  if (USE_MOCK_DATA) {
    const drivers = generateMockDrivers(15);
    const driver = drivers.find((d) => d.id === id);
    if (!driver) {
      return res.status(404).json({ success: false, error: 'Driver not found' });
    }
    return res.status(200).json({ success: true, data: driver });
  }
  // TODO: Database query
}

async function handleCreateDriver(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const driverData = req.body as Partial<Driver>;
  if (!driverData.name || !driverData.email || !driverData.organizationId) {
    return res
      .status(400)
      .json({ success: false, error: 'Missing required fields: name, email, organizationId' });
  }
  if (USE_MOCK_DATA) {
    const newDriver: Driver = {
      id: crypto.randomUUID(),
      organizationId: driverData.organizationId,
      name: driverData.name!,
      email: driverData.email!,
      phone: driverData.phone || '',
      status: (driverData.status as any) || 'available',
      rating: driverData.rating ?? 5.0,
      hoursWorked: driverData.hoursWorked ?? 0,
      totalHours: driverData.totalHours ?? 0,
      licenseNumber: driverData.licenseNumber,
      licenseExpiry: driverData.licenseExpiry ? new Date(driverData.licenseExpiry) : undefined,
      certifications: driverData.certifications,
      photoUrl: driverData.photoUrl,
      assignedVehicleId: driverData.assignedVehicleId,
      createdAt: new Date(),
      updatedAt: new Date(),
    } as Driver;

    return res
      .status(201)
      .json({ success: true, data: newDriver, message: 'Driver created successfully' });
  }
  // TODO: Database insert
}

async function handleUpdateDriver(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id, ...updates } = req.body || {};
  if (!id) {
    return res.status(400).json({ success: false, error: 'Driver ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({
      success: true,
      data: { id, ...updates, updatedAt: new Date() },
      message: 'Driver updated successfully',
    });
  }
  // TODO: Database update
}

async function handleDeleteDriver(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id } = req.query as { id?: string };
  if (!id) {
    return res.status(400).json({ success: false, error: 'Driver ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({ success: true, message: 'Driver deleted successfully' });
  }
  // TODO: Database delete
}
