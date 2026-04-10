import type { NextApiRequest, NextApiResponse } from 'next';
import type { Alert, ApiResponse } from '@/types/fleet';
import { generateMockAlerts } from '@/lib/fleet/mockData';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<Alert | Alert[]>>
) {
  const { method, query } = req;
  const { orgId, vehicleId, severity, acknowledged } = query as {
    orgId?: string;
    vehicleId?: string;
    severity?: string;
    acknowledged?: string;
  };

  try {
    switch (method) {
      case 'GET':
        return handleGetAlerts(req, res, orgId || '', { vehicleId, severity, acknowledged });
      case 'POST':
        return handleCreateAlert(req, res);
      case 'PUT':
        return handleAcknowledgeAlert(req, res);
      case 'DELETE':
        return handleDeleteAlert(req, res);
      default:
        res.setHeader('Allow', ['GET', 'POST', 'PUT', 'DELETE']);
        return res.status(405).json({ success: false, error: `Method ${method} Not Allowed` });
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Alerts API error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}

async function handleGetAlerts(
  _req: NextApiRequest,
  res: NextApiResponse,
  _orgId: string,
  filters: { vehicleId?: string; severity?: string; acknowledged?: string }
) {
  if (USE_MOCK_DATA) {
    let alerts = generateMockAlerts(10);

    if (filters.vehicleId) alerts = alerts.filter((a) => a.vehicleId === filters.vehicleId);
    if (filters.severity) alerts = alerts.filter((a) => a.severity === filters.severity);
    if (typeof filters.acknowledged !== 'undefined') {
      const ack = filters.acknowledged === 'true';
      alerts = alerts.filter((a) => a.acknowledged === ack);
    }

    alerts.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

    return res.status(200).json({ success: true, data: alerts });
  }
  // TODO: Database query
}

async function handleCreateAlert(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const alertData = req.body as Partial<Alert>;
  if (!alertData.type || !alertData.severity || !alertData.organizationId) {
    return res
      .status(400)
      .json({ success: false, error: 'Missing required fields: type, severity, organizationId' });
  }
  if (USE_MOCK_DATA) {
    const newAlert: Alert = {
      id: crypto.randomUUID(),
      organizationId: alertData.organizationId!,
      vehicleId: alertData.vehicleId,
      driverId: alertData.driverId,
      loadId: alertData.loadId,
      type: alertData.type as any,
      severity: alertData.severity as any,
      title: alertData.title || 'Alert',
      message: alertData.message || '',
      acknowledged: false,
      acknowledgedBy: undefined,
      acknowledgedAt: undefined,
      resolved: false,
      resolvedAt: undefined,
      metadata: alertData.metadata,
      timestamp: new Date(),
    };
    return res
      .status(201)
      .json({ success: true, data: newAlert, message: 'Alert created successfully' });
  }
  // TODO: Database insert
}

async function handleAcknowledgeAlert(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id, acknowledgedBy } = req.body || {};
  if (!id) {
    return res.status(400).json({ success: false, error: 'Alert ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({
      success: true,
      data: {
        id,
        acknowledged: true,
        acknowledgedBy,
        acknowledgedAt: new Date(),
      },
      message: 'Alert acknowledged successfully',
    });
  }
  // TODO: Database update
}

async function handleDeleteAlert(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const { id } = req.query as { id?: string };
  if (!id) {
    return res.status(400).json({ success: false, error: 'Alert ID is required' });
  }
  if (USE_MOCK_DATA) {
    return res.status(200).json({ success: true, message: 'Alert deleted successfully' });
  }
  // TODO: Database delete
}
