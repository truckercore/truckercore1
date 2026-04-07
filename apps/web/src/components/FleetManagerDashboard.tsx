import React, { useEffect, useState } from 'react';
import { Truck, Users, AlertTriangle, CheckCircle, Clock, TrendingUp } from 'lucide-react';
import type { Load } from '../types/freight';
import TestingHelper from './TestingHelper';
import PerformanceMonitor from './common/PerformanceMonitor';

interface FleetVehicle {
  id: string;
  truckNumber: string;
  driverName: string;
  status: 'available' | 'assigned' | 'in_transit' | 'maintenance';
  currentLocation: string;
  currentLoad?: Load;
  nextAvailable: string;
  maintenanceDue: string;
  insuranceExpiry: string;
  milesThisMonth: number;
  totalMiles: number;
}

interface FleetManagerDashboardProps {
  fleetName: string;
  managerId: string;
}

import { DashboardNavigation } from './DashboardNavigation';

export const FleetManagerDashboard: React.FC<FleetManagerDashboardProps> = ({
  fleetName,
  managerId,
}) => {
  const [vehicles, setVehicles] = useState<FleetVehicle[]>([]);
  const [fleetMetrics, setFleetMetrics] = useState({
    totalRevenue: 0,
    activeLoads: 0,
    availableVehicles: 0,
    maintenanceAlerts: 0,
    utilizationRate: 0,
    avgRevenuePerVehicle: 0,
  });
  const [alertsCount, setAlertsCount] = useState({
    insurance: 0,
    maintenance: 0,
    compliance: 0,
  });

  useEffect(() => {
    loadFleetData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [managerId]);

  const loadFleetData = () => {
    const mockVehicles: FleetVehicle[] = [
      {
        id: 'TRUCK-001',
        truckNumber: 'FL-1001',
        driverName: 'John Smith',
        status: 'in_transit',
        currentLocation: 'Kansas City, MO',
        nextAvailable: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
        maintenanceDue: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString(),
        insuranceExpiry: new Date(Date.now() + 120 * 24 * 60 * 60 * 1000).toISOString(),
        milesThisMonth: 4500,
        totalMiles: 125000,
      },
      {
        id: 'TRUCK-002',
        truckNumber: 'FL-1002',
        driverName: 'Sarah Johnson',
        status: 'available',
        currentLocation: 'Dallas, TX',
        nextAvailable: new Date().toISOString(),
        maintenanceDue: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString(),
        insuranceExpiry: new Date(Date.now() + 25 * 24 * 60 * 60 * 1000).toISOString(),
        milesThisMonth: 3200,
        totalMiles: 98000,
      },
      {
        id: 'TRUCK-003',
        truckNumber: 'FL-1003',
        driverName: 'Mike Davis',
        status: 'maintenance',
        currentLocation: 'Houston, TX',
        nextAvailable: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
        maintenanceDue: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
        insuranceExpiry: new Date(Date.now() + 180 * 24 * 60 * 60 * 1000).toISOString(),
        milesThisMonth: 0,
        totalMiles: 156000,
      },
      {
        id: 'TRUCK-004',
        truckNumber: 'FL-1004',
        driverName: 'Emily Brown',
        status: 'assigned',
        currentLocation: 'Denver, CO',
        nextAvailable: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        maintenanceDue: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString(),
        insuranceExpiry: new Date(Date.now() + 150 * 24 * 60 * 60 * 1000).toISOString(),
        milesThisMonth: 5100,
        totalMiles: 142000,
      },
    ];

    setVehicles(mockVehicles);

    const totalRevenue = 48500;
    const activeLoads = mockVehicles.filter(
      (v) => v.status === 'in_transit' || v.status === 'assigned'
    ).length;
    const availableVehicles = mockVehicles.filter((v) => v.status === 'available').length;
    const maintenanceAlerts = mockVehicles.filter(
      (v) =>
        v.status === 'maintenance' ||
        new Date(v.maintenanceDue).getTime() - Date.now() < 30 * 24 * 60 * 60 * 1000
    ).length;
    const utilizationRate =
      ((mockVehicles.length - availableVehicles - maintenanceAlerts) / mockVehicles.length) *
      100;

    setFleetMetrics({
      totalRevenue,
      activeLoads,
      availableVehicles,
      maintenanceAlerts,
      utilizationRate,
      avgRevenuePerVehicle: totalRevenue / mockVehicles.length,
    });

    const insuranceAlerts = mockVehicles.filter(
      (v) => new Date(v.insuranceExpiry).getTime() - Date.now() < 30 * 24 * 60 * 60 * 1000
    ).length;
    const maintenanceAlertsCount = mockVehicles.filter(
      (v) => new Date(v.maintenanceDue).getTime() - Date.now() < 30 * 24 * 60 * 60 * 1000
    ).length;

    setAlertsCount({
      insurance: insuranceAlerts,
      maintenance: maintenanceAlertsCount,
      compliance: 0,
    });
  };

  const getVehicleStatusColor = (status: FleetVehicle['status']) => {
    const colors: Record<string, string> = {
      available: 'bg-green-100 text-green-800',
      assigned: 'bg-blue-100 text-blue-800',
      in_transit: 'bg-purple-100 text-purple-800',
      maintenance: 'bg-red-100 text-red-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  const isExpiringWithin30Days = (dateString: string) => {
    const date = new Date(dateString);
    const daysUntil = (date.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
    return daysUntil <= 30 && daysUntil > 0;
  };

  const getDaysUntil = (dateString: string) => {
    const date = new Date(dateString);
    return Math.ceil((date.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
  };

  return (
    <>
      <DashboardNavigation />
      <div className="min-h-screen bg-gray-50">
      <div className="bg-gradient-to-r from-purple-600 to-purple-800 text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold">Fleet Manager Dashboard</h1>
              <p className="text-purple-100 mt-1">{fleetName}</p>
            </div>
            <div className="text-right">
              <p className="text-sm text-purple-100">Fleet Size</p>
              <p className="text-3xl font-bold">{vehicles.length} Vehicles</p>
            </div>
          </div>
        </div>
      </div>

      {(alertsCount.insurance > 0 || alertsCount.maintenance > 0 || alertsCount.compliance > 0) && (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 rounded">
            <div className="flex items-start">
              <AlertTriangle className="text-yellow-400 mr-3 mt-0.5" size={20} />
              <div>
                <h3 className="text-sm font-medium text-yellow-800">Action Required</h3>
                <div className="mt-2 text-sm text-yellow-700 flex gap-4">
                  {alertsCount.insurance > 0 && (
                    <span>⚠️ {alertsCount.insurance} insurance expiring soon</span>
                  )}
                  {alertsCount.maintenance > 0 && (
                    <span>🔧 {alertsCount.maintenance} maintenance due soon</span>
                  )}
                  {alertsCount.compliance > 0 && (
                    <span>📋 {alertsCount.compliance} compliance issues</span>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-6">
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex flex-col">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-600">Revenue</p>
                <TrendingUp className="text-green-600" size={20} />
              </div>
              <p className="text-2xl font-bold text-gray-900">
                ${fleetMetrics.totalRevenue.toLocaleString()}
              </p>
              <p className="text-xs text-gray-500 mt-1">This month</p>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex flex-col">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-600">Active Loads</p>
                <Truck className="text-blue-600" size={20} />
              </div>
              <p className="text-2xl font-bold text-gray-900">{fleetMetrics.activeLoads}</p>
              <p className="text-xs text-gray-500 mt-1">In progress</p>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex flex-col">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-600">Available</p>
                <CheckCircle className="text-green-600" size={20} />
              </div>
              <p className="text-2xl font-bold text-gray-900">
                {fleetMetrics.availableVehicles}
              </p>
              <p className="text-xs text-gray-500 mt-1">Ready to go</p>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex flex-col">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-600">Maintenance</p>
                <AlertTriangle className="text-red-600" size={20} />
              </div>
              <p className="text-2xl font-bold text-gray-900">
                {fleetMetrics.maintenanceAlerts}
              </p>
              <p className="text-xs text-gray-500 mt-1">Needs attention</p>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex flex-col">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-600">Utilization</p>
                <Clock className="text-purple-600" size={20} />
              </div>
              <p className="text-2xl font-bold text-gray-900">
                {fleetMetrics.utilizationRate.toFixed(0)}%
              </p>
              <p className="text-xs text-gray-500 mt-1">Fleet usage</p>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex flex-col">
              <div className="flex items-center justify-between mb-2">
                <p className="text-sm text-gray-600">Avg/Vehicle</p>
                <Users className="text-yellow-600" size={20} />
              </div>
              <p className="text-2xl font-bold text-gray-900">
                ${Math.round(fleetMetrics.avgRevenuePerVehicle).toLocaleString()}
              </p>
              <p className="text-xs text-gray-500 mt-1">Monthly</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow mt-6 overflow-hidden">
          <div className="px-6 py-4 border-b">
            <h3 className="text-lg font-semibold">Fleet Vehicles</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Truck #
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Driver
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Location
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Next Available
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Miles (Month)
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Maintenance Due
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                    Insurance
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {vehicles.map((vehicle) => (
                  <tr key={vehicle.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <Truck className="text-gray-400 mr-2" size={20} />
                        <span className="font-semibold text-gray-900">
                          {vehicle.truckNumber}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {vehicle.driverName}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span
                        className={`px-2 py-1 text-xs font-semibold rounded-full ${getVehicleStatusColor(
                          vehicle.status
                        )}`}
                      >
                        {vehicle.status.replace('_', ' ').toUpperCase()}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {vehicle.currentLocation}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {new Date(vehicle.nextAvailable).toLocaleDateString()}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      <div className="text-gray-900 font-semibold">
                        {vehicle.milesThisMonth.toLocaleString()}
                      </div>
                      <div className="text-xs text-gray-500">
                        Total: {(vehicle.totalMiles / 1000).toFixed(0)}K
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      {isExpiringWithin30Days(vehicle.maintenanceDue) ? (
                        <div className="text-red-600 font-semibold flex items-center gap-1">
                          <AlertTriangle size={16} />
                          {getDaysUntil(vehicle.maintenanceDue)} days
                        </div>
                      ) : (
                        <div className="text-gray-900">
                          {new Date(vehicle.maintenanceDue).toLocaleDateString()}
                        </div>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm">
                      {isExpiringWithin30Days(vehicle.insuranceExpiry) ? (
                        <div className="text-red-600 font-semibold flex items-center gap-1">
                          <AlertTriangle size={16} />
                          {getDaysUntil(vehicle.insuranceExpiry)} days
                        </div>
                      ) : (
                        <div className="text-green-600 font-semibold flex items-center gap-1">
                          <CheckCircle size={16} />
                          Valid
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-6">
          <div className="bg-white rounded-lg shadow p-6">
            <h4 className="font-semibold mb-3">Quick Assign</h4>
            <p className="text-sm text-gray-600 mb-4">
              Assign available drivers to new loads
            </p>
            <button className="w-full px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 font-semibold">
              View Available Loads
            </button>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h4 className="font-semibold mb-3">Schedule Maintenance</h4>
            <p className="text-sm text-gray-600 mb-4">
              Plan maintenance for your fleet vehicles
            </p>
            <button className="w-full px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 font-semibold">
              Schedule Service
            </button>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h4 className="font-semibold mb-3">Fleet Reports</h4>
            <p className="text-sm text-gray-600 mb-4">Generate performance and compliance reports</p>
            <button className="w-full px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 font-semibold">
              Generate Report
            </button>
          </div>
        </div>
      </div>
    </div>
    {process.env.NEXT_PUBLIC_ENABLE_PERFORMANCE_MONITOR === 'true' && <PerformanceMonitor />}
    <TestingHelper />
    </>
  );
};

export default FleetManagerDashboard;
