import React, { useEffect, useState } from 'react';
import { Truck, DollarSign, TrendingUp, MapPin } from 'lucide-react';
import type { Load } from '../types/freight';

interface OwnerOperatorDashboardProps {
  operatorId: string;
  operatorName: string;
  mcNumber: string;
}

interface AvailableLoad extends Load {
  matchScore?: number;
  estimatedProfit?: number;
}

import { DashboardNavigation } from './DashboardNavigation';

export const OwnerOperatorDashboard: React.FC<OwnerOperatorDashboardProps> = ({
  operatorId,
  operatorName,
  mcNumber,
}) => {
  const [myLoads, setMyLoads] = useState<Load[]>([]);
  const [availableLoads, setAvailableLoads] = useState<AvailableLoad[]>([]);
  const [earnings, setEarnings] = useState({
    thisWeek: 0,
    thisMonth: 0,
    thisYear: 0,
    avgPerLoad: 0,
  });
  const [vehicleStatus, setVehicleStatus] = useState({
    currentLocation: 'Dallas, TX',
    nextAvailable: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
    milesThisMonth: 8450,
    fuelEfficiency: 6.2,
  });

  useEffect(() => {
    loadOperatorData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [operatorId]);

  const loadOperatorData = () => {
    const mockMyLoads: Load[] = [
      {
        id: 'LOAD-OO-001',
        customerId: 'BROKER-001',
        customerName: 'ABC Freight Brokers',
        carrierId: operatorId,
        carrierName: operatorName,
        status: 'in_transit',
        pickupLocation: {
          address: '123 Industrial Blvd',
          city: 'Dallas',
          state: 'TX',
          zipCode: '75201',
        },
        deliveryLocation: {
          address: '456 Commerce St',
          city: 'Denver',
          state: 'CO',
          zipCode: '80201',
        },
        pickupDate: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
        deliveryDate: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        equipmentType: 'dry_van',
        weight: 42000,
        distance: 780,
        commodity: 'Electronics',
        customerRate: 2800,
        carrierRate: 2340,
        margin: 460,
        marginPercentage: 16.4,
        documents: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ];

    const mockAvailableLoads: AvailableLoad[] = [
      {
        id: 'LOAD-AVL-001',
        customerId: 'BROKER-002',
        customerName: 'XYZ Logistics',
        status: 'posted',
        pickupLocation: {
          address: '789 Warehouse Way',
          city: 'Denver',
          state: 'CO',
          zipCode: '80202',
        },
        deliveryLocation: {
          address: '321 Distribution Dr',
          city: 'Phoenix',
          state: 'AZ',
          zipCode: '85001',
        },
        pickupDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
        deliveryDate: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000).toISOString(),
        equipmentType: 'dry_van',
        weight: 38000,
        distance: 650,
        commodity: 'Consumer Goods',
        customerRate: 0,
        carrierRate: 2100,
        documents: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        matchScore: 92,
        estimatedProfit: 1890,
      },
      {
        id: 'LOAD-AVL-002',
        customerId: 'BROKER-003',
        customerName: 'Swift Brokers',
        status: 'posted',
        pickupLocation: {
          address: '555 Factory Rd',
          city: 'Phoenix',
          state: 'AZ',
          zipCode: '85003',
        },
        deliveryLocation: {
          address: '888 Retail Blvd',
          city: 'Los Angeles',
          state: 'CA',
          zipCode: '90001',
        },
        pickupDate: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
        deliveryDate: new Date(Date.now() + 6 * 24 * 60 * 60 * 1000).toISOString(),
        equipmentType: 'dry_van',
        weight: 44000,
        distance: 370,
        commodity: 'Furniture',
        customerRate: 0,
        carrierRate: 1250,
        documents: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        matchScore: 88,
        estimatedProfit: 1020,
      },
    ];

    setMyLoads(mockMyLoads);
    setAvailableLoads(mockAvailableLoads);

    const totalThisMonth = 12500;
    const totalThisWeek = 3200;
    const totalThisYear = 145000;
    const totalLoads = 52;

    setEarnings({
      thisWeek: totalThisWeek,
      thisMonth: totalThisMonth,
      thisYear: totalThisYear,
      avgPerLoad: totalThisYear / totalLoads,
    });
  };

  const handleAcceptLoad = (loadId: string) => {
    const load = availableLoads.find((l) => l.id === loadId);
    if (load) {
      const acceptedLoad: Load = {
        ...load,
        carrierId: operatorId,
        carrierName: operatorName,
        status: 'assigned',
      } as Load;
      setMyLoads([...myLoads, acceptedLoad]);
      setAvailableLoads(availableLoads.filter((l) => l.id !== loadId));
      alert(`Load ${loadId} accepted successfully!`);
    }
  };

  const handleUpdateStatus = (loadId: string, newStatus: Load['status']) => {
    setMyLoads((prev) => prev.map((load) => (load.id === loadId ? { ...load, status: newStatus } : load)));
  };

  const calculateFuelCost = (distance: number) => {
    const fuelPrice = 3.75; // per gallon
    const mpg = vehicleStatus.fuelEfficiency;
    return Math.round((distance / mpg) * fuelPrice);
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      posted: 'bg-yellow-100 text-yellow-800',
      assigned: 'bg-blue-100 text-blue-800',
      in_transit: 'bg-purple-100 text-purple-800',
      delivered: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  return (
    <>
      <DashboardNavigation />
      <div className="min-h-screen bg-gray-50">
      <div className="bg-gradient-to-r from-blue-600 to-blue-800 text-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold">Owner Operator Dashboard</h1>
              <p className="text-blue-100 mt-1">{operatorName} - MC# {mcNumber}</p>
            </div>
            <div className="text-right">
              <p className="text-sm text-blue-100">Current Location</p>
              <p className="text-xl font-semibold flex items-center gap-2 justify-end">
                <MapPin size={20} />
                {vehicleStatus.currentLocation}
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">This Week</p>
                <p className="text-2xl font-bold text-gray-900">
                  ${earnings.thisWeek.toLocaleString()}
                </p>
              </div>
              <div className="bg-green-100 p-3 rounded-full">
                <DollarSign className="text-green-600" size={24} />
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">This Month</p>
                <p className="text-2xl font-bold text-gray-900">
                  ${earnings.thisMonth.toLocaleString()}
                </p>
              </div>
              <div className="bg-blue-100 p-3 rounded-full">
                <TrendingUp className="text-blue-600" size={24} />
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Year to Date</p>
                <p className="text-2xl font-bold text-gray-900">
                  ${earnings.thisYear.toLocaleString()}
                </p>
              </div>
              <div className="bg-purple-100 p-3 rounded-full">
                <Truck className="text-purple-600" size={24} />
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600">Avg Per Load</p>
                <p className="text-2xl font-bold text-gray-900">
                  ${Math.round(earnings.avgPerLoad).toLocaleString()}
                </p>
              </div>
              <div className="bg-yellow-100 p-3 rounded-full">
                <DollarSign className="text-yellow-600" size={24} />
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6 mt-6">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <Truck className="text-blue-600" />
            Vehicle Status
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <p className="text-sm text-gray-600">Next Available</p>
              <p className="text-lg font-semibold text-gray-900">
                {new Date(vehicleStatus.nextAvailable).toLocaleDateString()}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Miles This Month</p>
              <p className="text-lg font-semibold text-gray-900">
                {vehicleStatus.milesThisMonth.toLocaleString()} mi
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Fuel Efficiency</p>
              <p className="text-lg font-semibold text-gray-900">
                {vehicleStatus.fuelEfficiency} MPG
              </p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow mt-6">
          <div className="px-6 py-4 border-b">
            <h3 className="text-lg font-semibold">My Active Loads</h3>
          </div>
          <div className="divide-y">
            {myLoads.length === 0 ? (
              <div className="p-8 text-center text-gray-500">
                <Truck className="mx-auto mb-2 text-gray-300" size={48} />
                <p>No active loads</p>
              </div>
            ) : (
              myLoads.map((load) => (
                <div key={load.id} className="p-6 hover:bg-gray-50">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <div className="flex items-center gap-3">
                        <h4 className="font-semibold text-lg">{load.id}</h4>
                        <span
                          className={`px-2 py-1 text-xs font-semibold rounded-full ${getStatusColor(
                            load.status
                          )}`}
                        >
                          {load.status.replace('_', ' ').toUpperCase()}
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 mt-1">
                        Broker: {load.customerName}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className="text-2xl font-bold text-green-600">
                        ${load.carrierRate?.toLocaleString()}
                      </p>
                      <p className="text-xs text-gray-500">{load.distance} miles</p>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div className="flex items-start gap-2">
                      <div className="bg-blue-100 p-2 rounded">
                        <MapPin className="text-blue-600" size={16} />
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Pickup</p>
                        <p className="font-semibold">
                          {load.pickupLocation.city}, {load.pickupLocation.state}
                        </p>
                        <p className="text-sm text-gray-600">
                          {new Date(load.pickupDate).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-start gap-2">
                      <div className="bg-green-100 p-2 rounded">
                        <MapPin className="text-green-600" size={16} />
                      </div>
                      <div>
                        <p className="text-xs text-gray-500">Delivery</p>
                        <p className="font-semibold">
                          {load.deliveryLocation.city}, {load.deliveryLocation.state}
                        </p>
                        <p className="text-sm text-gray-600">
                          {new Date(load.deliveryDate).toLocaleDateString()}
                        </p>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-3 border-t">
                    <div className="flex gap-4 text-sm">
                      <span className="text-gray-600">
                        <strong>Commodity:</strong> {load.commodity}
                      </span>
                      <span className="text-gray-600">
                        <strong>Weight:</strong> {load.weight.toLocaleString()} lbs
                      </span>
                      <span className="text-gray-600">
                        <strong>Equipment:</strong> {load.equipmentType.replace('_', ' ')}
                      </span>
                    </div>
                    {load.status === 'assigned' && (
                      <button
                        onClick={() => handleUpdateStatus(load.id, 'in_transit')}
                        className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm font-semibold"
                      >
                        Start Transit
                      </button>
                    )}
                    {load.status === 'in_transit' && (
                      <button
                        onClick={() => handleUpdateStatus(load.id, 'delivered')}
                        className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 text-sm font-semibold"
                      >
                        Mark Delivered
                      </button>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        <div className="bg-white rounded-lg shadow mt-6">
          <div className="px-6 py-4 border-b">
            <h3 className="text-lg font-semibold">Available Loads Near You</h3>
            <p className="text-sm text-gray-600">Matched based on your location and preferences</p>
          </div>
          <div className="divide-y">
            {availableLoads.map((load) => (
              <div key={load.id} className="p-6 hover:bg-gray-50">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <div className="flex items-center gap-3">
                      <h4 className="font-semibold text-lg">{load.id}</h4>
                      {typeof load.matchScore !== 'undefined' && (
                        <span className="px-2 py-1 bg-green-100 text-green-800 text-xs font-semibold rounded-full">
                          {load.matchScore}% Match
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-600 mt-1">Broker: {load.customerName}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-2xl font-bold text-blue-600">
                      ${load.carrierRate?.toLocaleString()}
                    </p>
                    <p className="text-xs text-gray-500">{load.distance} miles</p>
                    {typeof load.estimatedProfit !== 'undefined' && (
                      <p className="text-sm text-green-600 font-semibold">
                        Est. profit: ${load.estimatedProfit.toLocaleString()}
                      </p>
                    )}
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div className="flex items-start gap-2">
                    <div className="bg-blue-100 p-2 rounded">
                      <MapPin className="text-blue-600" size={16} />
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Pickup</p>
                      <p className="font-semibold">
                        {load.pickupLocation.city}, {load.pickupLocation.state}
                      </p>
                      <p className="text-sm text-gray-600">
                        {new Date(load.pickupDate).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-start gap-2">
                    <div className="bg-green-100 p-2 rounded">
                      <MapPin className="text-green-600" size={16} />
                    </div>
                    <div>
                      <p className="text-xs text-gray-500">Delivery</p>
                      <p className="font-semibold">
                        {load.deliveryLocation.city}, {load.deliveryLocation.state}
                      </p>
                      <p className="text-sm text-gray-600">
                        {new Date(load.deliveryDate).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="bg-gray-50 p-3 rounded mb-4">
                  <div className="grid grid-cols-3 gap-4 text-sm">
                    <div>
                      <p className="text-gray-600">Commodity</p>
                      <p className="font-semibold">{load.commodity}</p>
                    </div>
                    <div>
                      <p className="text-gray-600">Weight</p>
                      <p className="font-semibold">{load.weight.toLocaleString()} lbs</p>
                    </div>
                    <div>
                      <p className="text-gray-600">Est. Fuel Cost</p>
                      <p className="font-semibold text-red-600">
                        ${calculateFuelCost(load.distance)}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="flex justify-between items-center">
                  <button className="px-4 py-2 border border-gray-300 rounded hover:bg-gray-50 text-sm font-semibold">
                    View Details
                  </button>
                  <button
                    onClick={() => handleAcceptLoad(load.id)}
                    className="px-6 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm font-semibold"
                  >
                    Accept Load
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
    </>
  );
};

export default OwnerOperatorDashboard;
