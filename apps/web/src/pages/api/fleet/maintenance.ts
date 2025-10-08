import type { NextApiRequest, NextApiResponse } from 'next';
import type { MaintenanceRecord, ApiResponse } from '@/types/fleet';
import { generateMockMaintenanceRecords } from '@/lib/fleet/mockData';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<MaintenanceRecord | MaintenanceRecord[]>>
) {
  const { method, query } = req;
  const { orgId, vehicleId, status } = query as { orgId?: string; vehicleId?: string; status?: string };

  try {
    switch (method) {
      case 'GET':
        return handleGetMaintenanceRecords(req, res, orgId || '', { vehicleId, status });
      case 'POST':
        return handleCreateMaintenanceRecord(req, res);
      case 'PUT':
        return handleUpdateMaintenanceRecord(req, res);
      case 'DELETE':
        return handleDeleteMaintenanceRecord(req, res);
      default:
        res.setHeader('Allow', ['GET', 'POST', 'PUT', 'DELETE']);
        return res.status(405).json({ success: false, error: `Method ${method} Not Allowed` });
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Maintenance API error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}

async function handleGetMaintenanceRecords(
  _req: NextApiRequest,
  res: NextApiResponse,
  _orgId: string,
  filters: { vehicleId?: string; status?: string }
) {
  if (USE_MOCK_DATA) {
    let records = generateMockMaintenanceRecords(15);
    if (filters.vehicleId) records = records.filter((r) => r.vehicleId === filters.vehicleId);
    if (filters.status) {
      const statuses = filters.status.split(',');
      records = records.filter((r) => statuses.includes(r.status));
    }
    records.sort(
      (a, b) => new Date(a.scheduledDate).getTime() - new Date(b.scheduledDate).getTime()
    );
    return res.status(200).json({ success: true, data: records });
  }
  // TODO: Database query
}

async function handleCreateMaintenanceRecord(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const recordData = req.body as Partial<MaintenanceRecord>;
  if (!recordData.vehicleId || !recordData.type || !recordData.scheduledDate) {
    return res
      .status(400)
      .json({ success: false, error: 'Missing required fields: vehicleId, type, scheduledDate' });
  }
  if (USE_MOCK_DATA) {
    const newRecord: MaintenanceRecord = {
      id: crypto.randomUUID(),
      vehicleId: recordData.vehicleId!,
      organizationId: recordData.organizationId || 'org-1',
      type: recordData.type as any,
      scheduledDate: new Date(recordData.scheduledDate),
      completedDate: undefined,
      status: (recordData.status as any) || 'scheduled',
      mileage: recordData.mileage || 0,
      cost: recordData.cost,
      laborCost: recordData.laborCost,
      partsCost: recordData.partsCost,
      notes: recordData.notes || '',
      technician: recordData.technician,
      vendor: recordData.vendor,
      invoiceNumber: recordData.invoiceNumber,
      nextDueDate: recordData.nextDueDate ? new Date(recordData.nextDueDate) : undefined,
      nextDueMileage: recordData.nextDueMileage,
      parts: recordData.parts || [],
      createdAt: new Date(),
      updatedAt: new Date(),
    } as MaintenanceRecord;

    return res
      .status(201)
      .json({ success: true, data: newRecord, message: 'Maintenance scheduled successfully' });
  }
  // TODO: Database insert
}

async function handleUpdateMaintenanceRecord(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id, ...updates } = req.body || {};
  if (!id) {
    return res.status(400).json({ success: false, error: 'Maintenance record ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({
      success: true,
      data: { id, ...updates, updatedAt: new Date() },
      message: 'Maintenance record updated successfully',
    });
  }
  // TODO: Database update
}

async function handleDeleteMaintenanceRecord(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id } = req.query as { id?: string };
  if (!id) {
    return res.status(400).json({ success: false, error: 'Maintenance record ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({ success: true, message: 'Maintenance record deleted successfully' });
  }
  // TODO: Database delete
}
