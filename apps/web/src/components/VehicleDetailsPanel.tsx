"use client";

import React, { useState } from 'react';
import { X, Truck, User, Gauge, Navigation, Clock, MapPin, AlertTriangle } from 'lucide-react';
import type { Vehicle } from '@/types/fleet';
import { useFleetStore } from '@/stores/fleetStore';
import { formatSpeed } from '@/lib/fleet/mapUtils';

interface VehicleDetailsPanelProps {
  vehicle: Vehicle;
  onClose: () => void;
}

export default function VehicleDetailsPanel({ vehicle, onClose }: VehicleDetailsPanelProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'history' | 'maintenance'>('overview');
  const alerts = useFleetStore((s) => s.alerts.filter((a) => a.vehicleId === vehicle.id && !a.acknowledged));
  const maintenanceRecords = useFleetStore((s) =>
    s.maintenanceRecords
      .filter((r) => r.vehicleId === vehicle.id)
      .sort((a, b) => new Date(b.scheduledDate).getTime() - new Date(a.scheduledDate).getTime())
      .slice(0, 5)
  );

  return (
    <div className="fixed bottom-4 left-4 w-96 bg-white rounded-lg shadow-2xl border z-30 max-h-[600px] flex flex-col">
      <div className="p-4 border-b flex items-start justify-between bg-gradient-to-r from-blue-50 to-white">
        <div className="flex items-start gap-3">
          <div className={`p-2 rounded-lg ${getStatusColor(vehicle.status)}`}>
            <Truck className="w-6 h-6" />
          </div>
          <div>
            <h3 className="font-semibold text-lg">{vehicle.name}</h3>
            <p className="text-sm text-gray-600 capitalize">{vehicle.type}</p>
            <StatusBadge status={vehicle.status} />
          </div>
        </div>
        <button onClick={onClose} className="text-gray-400 hover:text-gray-600 transition-colors">
          <X className="w-5 h-5" />
        </button>
      </div>

      <div className="flex border-b">
        <TabButton active={activeTab === 'overview'} onClick={() => setActiveTab('overview')} label="Overview" />
        <TabButton active={activeTab === 'history'} onClick={() => setActiveTab('history')} label="History" />
        <TabButton active={activeTab === 'maintenance'} onClick={() => setActiveTab('maintenance')} label="Maintenance" badge={maintenanceRecords.filter((r) => r.status === 'overdue').length} />
      </div>

      <div className="flex-1 overflow-y-auto p-4">
        {activeTab === 'overview' && <OverviewTab vehicle={vehicle} alerts={alerts} />}
        {activeTab === 'history' && <HistoryTab vehicle={vehicle} />}
        {activeTab === 'maintenance' && <MaintenanceTab records={maintenanceRecords} />}
      </div>
    </div>
  );
}

function OverviewTab({ vehicle, alerts }: { vehicle: Vehicle; alerts: any[] }) {
  return (
    <div className="space-y-4">
      {alerts.length > 0 && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-2">
            <AlertTriangle className="w-4 h-4 text-red-600" />
            <h4 className="font-medium text-red-900">Active Alerts ({alerts.length})</h4>
          </div>
          {alerts.map((a) => (
            <div key={a.id} className="text-sm text-red-800 mb-1">• {a.message}</div>
          ))}
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        <MetricCard icon={<Gauge className="w-5 h-5" />} label="Speed" value={formatSpeed(vehicle.location.speed)} color="blue" />
        <MetricCard icon={<Navigation className="w-5 h-5" />} label="Heading" value={`${vehicle.location.heading.toFixed(0)}°`} color="green" />
        <MetricCard icon={<Gauge className="w-5 h-5" />} label="Fuel Level" value={`${vehicle.fuel.toFixed(0)}%`} color={vehicle.fuel < 25 ? 'red' : 'yellow'} />
        <MetricCard icon={<Clock className="w-5 h-5" />} label="Odometer" value={`${vehicle.odometer.toLocaleString()} mi`} color="purple" />
      </div>

      <div className="bg-gray-50 rounded-lg p-3">
        <div className="flex items-center gap-2 mb-2">
          <MapPin className="w-4 h-4 text-gray-600" />
          <h4 className="font-medium text-gray-900">Current Location</h4>
        </div>
        <p className="text-sm text-gray-700">{vehicle.location.lat.toFixed(6)}, {vehicle.location.lng.toFixed(6)}</p>
        <p className="text-xs text-gray-500 mt-1">Last updated: {new Date(vehicle.lastUpdate).toLocaleString()}</p>
      </div>

      {vehicle.driver && (
        <div className="bg-gray-50 rounded-lg p-3">
          <div className="flex items-center gap-2 mb-2">
            <User className="w-4 h-4 text-gray-600" />
            <h4 className="font-medium text-gray-900">Current Driver</h4>
          </div>
          <p className="text-sm font-medium text-gray-900">{vehicle.driver.name}</p>
          <div className="flex items-center gap-4 mt-2 text-sm text-gray-600">
            <span>Rating: {vehicle.driver.rating.toFixed(1)} ★</span>
            <span>Hours: {vehicle.driver.hoursWorked.toFixed(1)}h</span>
          </div>
        </div>
      )}

      <div className="border-t pt-4 space-y-2 text-sm">
        <DetailRow label="VIN" value={vehicle.vin || 'N/A'} />
        <DetailRow label="Make/Model" value={`${vehicle.make || 'N/A'} ${vehicle.model || ''}`.trim()} />
        <DetailRow label="Year" value={vehicle.year?.toString() || 'N/A'} />
        <DetailRow label="License Plate" value={vehicle.licensePlate || 'N/A'} />
        <DetailRow label="Capacity" value={vehicle.capacity ? `${vehicle.capacity.toLocaleString()} lbs` : 'N/A'} />
      </div>
    </div>
  );
}

function HistoryTab({ vehicle }: { vehicle: Vehicle }) {
  const historyPoints = Array.from({ length: 10 }, (_, i) => {
    const date = new Date();
    date.setHours(date.getHours() - i);
    return { timestamp: date, location: `Location ${i + 1}`, speed: 45 + Math.random() * 20, event: i % 3 === 0 ? 'Stop' : 'Moving' };
  });

  return (
    <div className="space-y-3">
      <h4 className="font-medium text-gray-900">Recent Activity</h4>
      {historyPoints.map((p, idx) => (
        <div key={idx} className="flex items-start gap-3 pb-3 border-b last:border-0">
          <div className="flex-shrink-0 w-2 h-2 mt-2 rounded-full bg-blue-500" />
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-gray-900">{p.event}</p>
            <p className="text-xs text-gray-600">{p.location}</p>
            <div className="flex items-center gap-3 mt-1">
              <span className="text-xs text-gray-500">{formatSpeed(p.speed)}</span>
              <span className="text-xs text-gray-400">{p.timestamp.toLocaleTimeString()}</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

function MaintenanceTab({ records }: { records: any[] }) {
  return (
    <div className="space-y-3">
      <h4 className="font-medium text-gray-900">Recent Maintenance</h4>
      {records.length === 0 ? (
        <p className="text-sm text-gray-500 text-center py-8">No maintenance records found</p>
      ) : (
        records.map((r) => (
          <div key={r.id} className="border rounded-lg p-3">
            <div className="flex items-start justify-between mb-2">
              <div>
                <p className="text-sm font-medium text-gray-900 capitalize">{String(r.type).replace('-', ' ')}</p>
                <p className="text-xs text-gray-500">{new Date(r.scheduledDate).toLocaleDateString()}</p>
              </div>
              <StatusBadge status={r.status} />
            </div>
            {r.cost && <p className="text-sm text-gray-700">${r.cost.toFixed(2)}</p>}
            {r.notes && <p className="text-xs text-gray-600 mt-2">{r.notes}</p>}
          </div>
        ))
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    active: 'bg-green-100 text-green-700',
    idle: 'bg-yellow-100 text-yellow-700',
    maintenance: 'bg-red-100 text-red-700',
    offline: 'bg-gray-100 text-gray-700',
    completed: 'bg-green-100 text-green-700',
    scheduled: 'bg-blue-100 text-blue-700',
    overdue: 'bg-red-100 text-red-700',
  };
  return <span className={`inline-block px-2 py-1 rounded-full text-xs font-medium capitalize ${colors[status] || 'bg-gray-100 text-gray-700'}`}>{status}</span>;
}

function TabButton({ active, onClick, label, badge }: { active: boolean; onClick: () => void; label: string; badge?: number }) {
  return (
    <button onClick={onClick} className={`flex-1 px-4 py-2 text-sm font-medium border-b-2 transition-colors relative ${active ? 'border-blue-500 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}>
      {label}
      {badge !== undefined && badge > 0 && (
        <span className="absolute top-1 right-1 inline-flex items-center justify-center px-1.5 py-0.5 text-xs font-bold leading-none text-white bg-red-600 rounded-full">{badge}</span>
      )}
    </button>
  );
}

function MetricCard({ icon, label, value, color }: { icon: React.ReactNode; label: string; value: string; color: string }) {
  const colors: Record<string, string> = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    yellow: 'bg-yellow-50 text-yellow-600',
    red: 'bg-red-50 text-red-600',
    purple: 'bg-purple-50 text-purple-600',
  };
  return (
    <div className="bg-gray-50 rounded-lg p-3">
      <div className={`inline-flex p-2 rounded-lg mb-2 ${colors[color]}`}>{icon}</div>
      <p className="text-xs text-gray-600">{label}</p>
      <p className="text-lg font-semibold text-gray-900">{value}</p>
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between">
      <span className="text-gray-600">{label}:</span>
      <span className="font-medium text-gray-900">{value}</span>
    </div>
  );
}

function getStatusColor(status: Vehicle['status']) {
  const colors: Record<string, string> = {
    active: 'bg-green-100 text-green-700',
    idle: 'bg-yellow-100 text-yellow-700',
    maintenance: 'bg-red-100 text-red-700',
    offline: 'bg-gray-100 text-gray-700',
    loading: 'bg-blue-100 text-blue-700',
    unloading: 'bg-purple-100 text-purple-700',
  };
  return colors[status] || colors.offline;
}
