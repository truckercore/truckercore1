import type { NextApiRequest, NextApiResponse } from 'next';
import type { Load, ApiResponse } from '@/types/fleet';
import { generateMockLoads } from '@/lib/fleet/mockData';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<Load | Load[]>>
) {
  const { method, query } = req;
  const { orgId, id, status } = query as { orgId?: string; id?: string; status?: string };

  try {
    switch (method) {
      case 'GET':
        if (id) {
          return handleGetLoad(req, res, id);
        }
        return handleGetLoads(req, res, orgId || '', status);
      case 'POST':
        return handleCreateLoad(req, res);
      case 'PUT':
        return handleUpdateLoad(req, res);
      case 'DELETE':
        return handleDeleteLoad(req, res);
      default:
        res.setHeader('Allow', ['GET', 'POST', 'PUT', 'DELETE']);
        return res.status(405).json({ success: false, error: `Method ${method} Not Allowed` });
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Loads API error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}

async function handleGetLoads(
  _req: NextApiRequest,
  res: NextApiResponse,
  _orgId: string,
  status?: string
) {
  if (USE_MOCK_DATA) {
    let loads = generateMockLoads(20);
    if (status) {
      const statuses = status.split(',');
      loads = loads.filter((l) => statuses.includes(l.status));
    }
    return res.status(200).json({ success: true, data: loads });
  }
  // TODO: Database query
}

async function handleGetLoad(
  _req: NextApiRequest,
  res: NextApiResponse,
  id: string
) {
  if (USE_MOCK_DATA) {
    const loads = generateMockLoads(20);
    const load = loads.find((l) => l.id === id);
    if (!load) {
      return res.status(404).json({ success: false, error: 'Load not found' });
    }
    return res.status(200).json({ success: true, data: load });
  }
  // TODO: Database query
}

async function handleCreateLoad(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const loadData = req.body as Partial<Load>;
  if (!loadData.origin || !loadData.destination || !loadData.organizationId) {
    return res
      .status(400)
      .json({ success: false, error: 'Missing required fields: origin, destination, organizationId' });
  }
  if (USE_MOCK_DATA) {
    const newLoad: Load = {
      id: crypto.randomUUID(),
      organizationId: loadData.organizationId!,
      customerId: loadData.customerId,
      customerName: loadData.customerName,
      origin: loadData.origin as any,
      destination: loadData.destination as any,
      waypoints: loadData.waypoints || [],
      pickupTime: loadData.pickupTime ? new Date(loadData.pickupTime) : new Date(),
      deliveryTime: loadData.deliveryTime ? new Date(loadData.deliveryTime) : new Date(Date.now() + 86400000),
      weight: loadData.weight || 0,
      volume: loadData.volume,
      priority: (loadData.priority as any) || 'normal',
      status: (loadData.status as any) || 'pending',
      assignedVehicleId: loadData.assignedVehicleId,
      assignedDriverId: loadData.assignedDriverId,
      description: loadData.description,
      specialInstructions: loadData.specialInstructions,
      requiresSignature: loadData.requiresSignature ?? true,
      items: loadData.items || [],
      documents: loadData.documents || [],
      createdAt: new Date(),
      updatedAt: new Date(),
    } as Load;

    return res
      .status(201)
      .json({ success: true, data: newLoad, message: 'Load created successfully' });
  }
  // TODO: Database insert
}

async function handleUpdateLoad(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id, ...updates } = req.body || {};
  if (!id) {
    return res.status(400).json({ success: false, error: 'Load ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({
      success: true,
      data: { id, ...updates, updatedAt: new Date() },
      message: 'Load updated successfully',
    });
  }
  // TODO: Database update
}

async function handleDeleteLoad(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id } = req.query as { id?: string };
  if (!id) {
    return res.status(400).json({ success: false, error: 'Load ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({ success: true, message: 'Load deleted successfully' });
  }
  // TODO: Database delete
}
