'use client';

import { useEffect, useState } from 'react';

interface Driver {
  id: string;
  name: string;
  vehicle_id?: string;
  status: string;
}

interface Vehicle {
  id: string;
  truck_number: string;
  make?: string;
  model?: string;
  year?: number;
  status: string;
}

export default function VehicleAssignmentPanel({ orgId }: { orgId: string }) {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [message, setMessage] = useState('');
  const [showAddVehicle, setShowAddVehicle] = useState(false);
  const [newTruck, setNewTruck] = useState('');
  const [addingVehicle, setAddingVehicle] = useState(false);

  const loadData = () => {
    fetch(`/api/drivers/list?orgId=${orgId}`)
      .then(r => r.json())
      .then(d => setDrivers(d.drivers || []))
      .catch(() => {});

    fetch('/api/vehicles')
      .then(r => r.json())
      .then(d => setVehicles(d.vehicles || []))
      .catch(() => {});
  };

  useEffect(() => { loadData(); }, [orgId]);

  const assignVehicle = async (driverId: string, vehicleId: string) => {
    try {
      await fetch('/api/drivers/assign-vehicle', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ driverId, vehicleId: vehicleId || null }),
      });
      setMessage('✓ Vehicle assigned');
      loadData();
      setTimeout(() => setMessage(''), 2000);
    } catch {
      setMessage('Assignment failed');
    }
  };

  const addVehicle = async () => {
    if (!newTruck.trim()) return;
    setAddingVehicle(true);
    try {
      const res = await fetch('/api/vehicles', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ truckNumber: newTruck }),
      });
      if (res.ok) {
        setNewTruck('');
        setShowAddVehicle(false);
        loadData();
      }
    } catch {
    } finally {
      setAddingVehicle(false);
    }
  };

  const getVehicleForDriver = (vehicleId?: string) => {
    return vehicles.find(v => v.id === vehicleId);
  };

  return (
    <div className="rounded-2xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="font-bold text-white">🚚 Vehicle Assignment</h2>
          <p className="text-xs text-gray-400">
            {vehicles.length} trucks · {drivers.length} drivers
          </p>
        </div>
        <button
          onClick={() => setShowAddVehicle(!showAddVehicle)}
          className="text-xs bg-gray-800 hover:bg-gray-700 text-white px-3 py-1.5 rounded-lg transition"
        >
          + Add Truck
        </button>
      </div>

      {/* Add vehicle form */}
      {showAddVehicle && (
        <div className="bg-gray-800 rounded-xl p-3 mb-4 flex gap-2">
          <input
            placeholder="Truck number (e.g. TC-105)"
            value={newTruck}
            onChange={e => setNewTruck(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && addVehicle()}
            className="flex-1 bg-gray-700 border border-gray-600 text-white text-sm px-3 py-2 rounded-lg focus:border-blue-500 outline-none"
          />
          <button
            onClick={addVehicle}
            disabled={addingVehicle || !newTruck.trim()}
            className="bg-blue-600 hover:bg-blue-700 disabled:opacity-40 text-white text-sm px-3 py-2 rounded-lg transition"
          >
            {addingVehicle ? '...' : 'Add'}
          </button>
        </div>
      )}

      {message && (
        <p className={`text-xs mb-3 ${message.startsWith('✓') ? 'text-green-400' : 'text-red-400'}`}>
          {message}
        </p>
      )}

      {/* Assignment table */}
      {drivers.length === 0 ? (
        <p className="text-gray-500 text-sm text-center py-4">
          Add drivers first to assign vehicles
        </p>
      ) : (
        <div className="space-y-2">
          {drivers.map(driver => {
            const assigned = getVehicleForDriver(driver.vehicle_id);
            return (
              <div key={driver.id} className="flex items-center justify-between bg-gray-800 rounded-xl px-3 py-2.5">
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-full bg-gray-700 flex items-center justify-center text-white text-xs font-bold">
                    {driver.name.charAt(0)}
                  </div>
                  <div>
                    <p className="text-white text-sm">{driver.name}</p>
                    {assigned && (
                      <p className="text-blue-400 text-xs">{assigned.truck_number}</p>
                    )}
                  </div>
                </div>
                <select
                  value={driver.vehicle_id || ''}
                  onChange={e => assignVehicle(driver.id, e.target.value)}
                  className="bg-gray-700 border border-gray-600 text-white text-xs rounded-lg px-2 py-1 focus:border-blue-500 outline-none"
                >
                  <option value="">No truck</option>
                  {vehicles.map(v => (
                    <option key={v.id} value={v.id}>
                      {v.truck_number}
                    </option>
                  ))}
                </select>
              </div>
            );
          })}
        </div>
      )}

      {/* Unassigned vehicles */}
      {vehicles.length > 0 && (
        <div className="mt-3 pt-3 border-t border-gray-800">
          <p className="text-xs text-gray-500 mb-2">
            {vehicles.filter(v => !drivers.some(d => d.vehicle_id === v.id)).length} unassigned trucks
          </p>
          <div className="flex flex-wrap gap-1">
            {vehicles
              .filter(v => !drivers.some(d => d.vehicle_id === v.id))
              .map(v => (
                <span key={v.id} className="text-xs bg-gray-800 text-gray-400 px-2 py-0.5 rounded">
                  {v.truck_number}
                </span>
              ))
            }
          </div>
        </div>
      )}
    </div>
  );
}
