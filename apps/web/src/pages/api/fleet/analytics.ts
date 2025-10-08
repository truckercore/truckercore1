import type { NextApiRequest, NextApiResponse } from 'next';
import type { FleetAnalytics, ApiResponse } from '@/types/fleet';

const USE_MOCK_DATA = true;

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse<FleetAnalytics>>
) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', ['GET']);
    return res.status(405).json({ success: false, error: `Method ${req.method} Not Allowed` });
  }

  const { orgId, range = '30d' } = req.query as { orgId?: string; range?: string };

  if (!orgId) {
    return res.status(400).json({ success: false, error: 'Organization ID is required' });
  }

  try {
    if (USE_MOCK_DATA) {
      const analytics = generateMockAnalytics(range as string);
      analytics.organizationId = orgId;
      return res.status(200).json({ success: true, data: analytics });
    }

    // TODO: Real analytics computation over DB data
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Analytics API error:', error);
    return res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Internal server error',
    });
  }
}

function generateMockAnalytics(range: string): FleetAnalytics {
  const days = range === '7d' ? 7 : range === '30d' ? 30 : 90;
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - days);

  const costHistory: { date: string; value: number }[] = [];
  for (let i = days; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    costHistory.push({ date: d.toLocaleDateString(), value: 1.5 + Math.random() * 0.5 });
  }

  return {
    organizationId: 'org-1',
    dateRange: { start: startDate, end: new Date() },
    costPerMile: {
      current: 1.75,
      previous: 1.82,
      trend: -3.8,
      history: costHistory,
      breakdown: { fuel: 0.65, maintenance: 0.35, labor: 0.45, insurance: 0.15, depreciation: 0.15 },
    },
    utilization: {
      rate: 78.5,
      byVehicle: [
        { vehicleId: '1', name: 'Truck A', rate: 85, activeHours: 170, idleHours: 20, maintenanceHours: 10 },
        { vehicleId: '2', name: 'Truck B', rate: 92, activeHours: 184, idleHours: 10, maintenanceHours: 6 },
        { vehicleId: '3', name: 'Truck C', rate: 68, activeHours: 136, idleHours: 50, maintenanceHours: 14 },
        { vehicleId: '4', name: 'Truck D', rate: 75, activeHours: 150, idleHours: 35, maintenanceHours: 15 },
        { vehicleId: '5', name: 'Truck E', rate: 88, activeHours: 176, idleHours: 15, maintenanceHours: 9 },
      ],
      byTimeOfDay: Array.from({ length: 24 }, (_, i) => ({ hour: i, utilization: Math.random() * 100 })),
      byDayOfWeek: [
        { day: 'Monday', utilization: 85 },
        { day: 'Tuesday', utilization: 88 },
        { day: 'Wednesday', utilization: 82 },
        { day: 'Thursday', utilization: 90 },
        { day: 'Friday', utilization: 87 },
        { day: 'Saturday', utilization: 65 },
        { day: 'Sunday', utilization: 45 },
      ],
    },
    driverPerformance: {
      drivers: [
        {
          id: '1',
          name: 'John Smith',
          efficiency: 92,
          onTimeDeliveries: 95,
          totalDeliveries: 48,
          averageDeliveryTime: 185,
          fuelEfficiency: 8.5,
          safetyScore: 98,
          incidents: 0,
          hoursWorked: 160,
        },
        {
          id: '2',
          name: 'Sarah Johnson',
          efficiency: 88,
          onTimeDeliveries: 91,
          totalDeliveries: 45,
          averageDeliveryTime: 195,
          fuelEfficiency: 8.2,
          safetyScore: 95,
          incidents: 1,
          hoursWorked: 155,
        },
        {
          id: '3',
          name: 'Mike Wilson',
          efficiency: 85,
          onTimeDeliveries: 87,
          totalDeliveries: 42,
          averageDeliveryTime: 210,
          fuelEfficiency: 7.9,
          safetyScore: 90,
          incidents: 2,
          hoursWorked: 165,
        },
      ],
    },
    fuelConsumption: {
      total: 2450,
      average: 8.5,
      cost: 8575,
      byVehicle: [
        { vehicleId: '1', name: 'Truck A', consumption: 520, mpg: 8.5, cost: 1820 },
        { vehicleId: '2', name: 'Truck B', consumption: 480, mpg: 8.8, cost: 1680 },
        { vehicleId: '3', name: 'Truck C', consumption: 550, mpg: 7.9, cost: 1925 },
        { vehicleId: '4', name: 'Truck D', consumption: 510, mpg: 8.3, cost: 1785 },
        { vehicleId: '5', name: 'Truck E', consumption: 390, mpg: 9.1, cost: 1365 },
      ],
      trend: costHistory.map((item) => ({ date: item.date, consumption: 80 + Math.random() * 20 })),
    },
    maintenanceCosts: {
      total: 15750,
      averagePerVehicle: 1575,
      byType: [
        { type: 'oil-change', cost: 3200, count: 32 },
        { type: 'tire-rotation', cost: 4500, count: 20 },
        { type: 'brake-service', cost: 2800, count: 8 },
        { type: 'inspection', cost: 1250, count: 25 },
        { type: 'repair', cost: 4000, count: 12 },
      ],
      byVehicle: [
        { vehicleId: '1', name: 'Truck A', cost: 2800, recordsCount: 8 },
        { vehicleId: '2', name: 'Truck B', cost: 1950, recordsCount: 6 },
        { vehicleId: '3', name: 'Truck C', cost: 3500, recordsCount: 12 },
        { vehicleId: '4', name: 'Truck D', cost: 2200, recordsCount: 7 },
        { vehicleId: '5', name: 'Truck E', cost: 1800, recordsCount: 5 },
      ],
      predictedCosts: { nextMonth: 5250, nextQuarter: 15750 },
    },
    deliveryMetrics: {
      totalDeliveries: 187,
      onTimeDeliveries: 169,
      lateDeliveries: 18,
      onTimePercentage: 90.4,
      averageDeliveryTime: 195,
      averageDistance: 285,
      byPriority: [
        { priority: 'urgent', count: 35, onTimePercentage: 94.3 },
        { priority: 'normal', count: 125, onTimePercentage: 89.6 },
        { priority: 'low', count: 27, onTimePercentage: 88.9 },
      ],
    },
    safetyMetrics: {
      totalIncidents: 12,
      incidentRate: 0.8,
      harshBraking: 45,
      harshAcceleration: 38,
      speedingEvents: 22,
      byDriver: [
        { driverId: '1', name: 'John Smith', safetyScore: 98, incidents: 0 },
        { driverId: '2', name: 'Sarah Johnson', safetyScore: 95, incidents: 1 },
        { driverId: '3', name: 'Mike Wilson', safetyScore: 90, incidents: 2 },
      ],
    },
  };
}
