"use client";

import React, { useState } from 'react';
import { MapPin, Plus, Edit2, Trash2, Eye, EyeOff, Save } from 'lucide-react';
import type { Geofence } from '@/types/fleet';
import { useGeofencing } from '@/hooks/useGeofencing';
import type maplibregl from 'maplibre-gl';

interface GeofenceManagerProps {
  organizationId: string;
  map?: maplibregl.Map;
  onGeofenceClick?: (geofence: Geofence) => void;
}

export default function GeofenceManager({ organizationId, map, onGeofenceClick }: GeofenceManagerProps) {
  const { geofences, createGeofence, updateGeofence, deleteGeofence } = useGeofencing({ organizationId, useMockData: true });
  const [isCreating, setIsCreating] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(true);

  const handleCreate = () => setIsCreating(true);

  const handleDelete = async (id: string) => {
    if (confirm('Are you sure you want to delete this geofence?')) await deleteGeofence(id);
  };

  const handleToggleActive = async (g: Geofence) => { await updateGeofence(g.id, { active: !g.active }); };

  return (
    <div className="bg-white rounded-lg shadow-lg">
      <div className="p-4 border-b flex items-center justify-between">
        <div className="flex items-center gap-2">
          <MapPin className="w-5 h-5 text-blue-600" />
          <h3 className="font-semibold text-lg">Geofences</h3>
          <span className="text-sm text-gray-500">({geofences.length})</span>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => setShowAll(!showAll)} className="p-2 text-gray-600 hover:text-gray-900 transition-colors" title={showAll ? 'Hide all' : 'Show all'}>
            {showAll ? <Eye className="w-5 h-5" /> : <EyeOff className="w-5 h-5" />}
          </button>
          <button onClick={handleCreate} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            <Plus className="w-4 h-4" />
            Create Geofence
          </button>
        </div>
      </div>

      <div className="divide-y max-h-96 overflow-y-auto">
        {geofences.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            <MapPin className="w-12 h-12 mx-auto mb-3 text-gray-300" />
            <p>No geofences created yet</p>
            <button onClick={handleCreate} className="mt-4 text-blue-600 hover:text-blue-700 font-medium">Create your first geofence</button>
          </div>
        ) : (
          geofences.map((g) => (
            <GeofenceItem
              key={g.id}
              geofence={g}
              isEditing={editingId === g.id}
              onEdit={() => setEditingId(g.id)}
              onCancelEdit={() => setEditingId(null)}
              onSave={async (updates) => { await updateGeofence(g.id, updates); setEditingId(null); }}
              onDelete={() => handleDelete(g.id)}
              onToggleActive={() => handleToggleActive(g)}
              onClick={() => onGeofenceClick?.(g)}
            />
          ))
        )}
      </div>

      {isCreating && (
        <CreateGeofenceDialog
          organizationId={organizationId}
          onSave={async (data) => { await createGeofence(data); setIsCreating(false); }}
          onCancel={() => setIsCreating(false)}
        />
      )}
    </div>
  );
}

function GeofenceItem({ geofence, isEditing, onEdit, onCancelEdit, onSave, onDelete, onToggleActive, onClick }: {
  geofence: Geofence; isEditing: boolean; onEdit: () => void; onCancelEdit: () => void; onSave: (updates: Partial<Geofence>) => void; onDelete: () => void; onToggleActive: () => void; onClick: () => void;
}) {
  const [name, setName] = useState(geofence.name);
  const [description, setDescription] = useState(geofence.description || '');
  const typeColors: Record<Geofence['type'], string> = {
    allowed: 'bg-green-100 text-green-700',
    restricted: 'bg-red-100 text-red-700',
    customer: 'bg-blue-100 text-blue-700',
    depot: 'bg-yellow-100 text-yellow-700',
    service: 'bg-purple-100 text-purple-700',
    parking: 'bg-gray-100 text-gray-700',
  };

  if (isEditing) {
    return (
      <div className="p-4 bg-blue-50">
        <div className="space-y-3">
          <input value={name} onChange={(e) => setName(e.target.value)} className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" placeholder="Geofence name" />
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" placeholder="Description" rows={2} />
          <div className="flex gap-2">
            <button onClick={() => onSave({ name, description })} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              <Save className="w-4 h-4" /> Save
            </button>
            <button onClick={onCancelEdit} className="px-4 py-2 border rounded-lg hover:bg-gray-50">Cancel</button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 hover:bg-gray-50 transition-colors cursor-pointer" onClick={onClick}>
      <div className="flex items-start justify-between">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-1">
            <h4 className="font-medium text-gray-900">{geofence.name}</h4>
            <span className={`px-2 py-0.5 rounded-full text-xs font-medium capitalize ${typeColors[geofence.type]}`}>{geofence.type}</span>
          </div>
          {geofence.description && <p className="text-sm text-gray-600 mb-2">{geofence.description}</p>}
          <div className="flex items-center gap-4 text-xs text-gray-500">
            <span>Entry Alert: {geofence.alertOnEntry ? '✓' : '✗'}</span>
            <span>Exit Alert: {geofence.alertOnExit ? '✓' : '✗'}</span>
          </div>
        </div>
        <div className="flex items-center gap-1 ml-4">
          <button onClick={(e) => { e.stopPropagation(); onToggleActive(); }} className={`p-2 rounded ${geofence.active ? 'text-green-600 hover:bg-green-50' : 'text-gray-400 hover:bg-gray-100'}`} title={geofence.active ? 'Active' : 'Inactive'}>
            {geofence.active ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
          </button>
          <button onClick={(e) => { e.stopPropagation(); onEdit(); }} className="p-2 text-gray-600 hover:bg-gray-100 rounded">
            <Edit2 className="w-4 h-4" />
          </button>
          <button onClick={(e) => { e.stopPropagation(); onDelete(); }} className="p-2 text-red-600 hover:bg-red-50 rounded">
            <Trash2 className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}

function CreateGeofenceDialog({ organizationId, onSave, onCancel }: { organizationId: string; onSave: (data: Omit<Geofence, 'id' | 'createdAt' | 'updatedAt'>) => void; onCancel: () => void; }) {
  const [name, setName] = useState('');
  const [type, setType] = useState<Geofence['type']>('allowed');
  const [description, setDescription] = useState('');
  const [alertOnEntry, setAlertOnEntry] = useState(true);
  const [alertOnExit, setAlertOnExit] = useState(true);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const coordinates: [number, number][] = [
      [-98.5795, 39.8283],
      [-98.5695, 39.8283],
      [-98.5695, 39.8383],
      [-98.5795, 39.8383],
      [-98.5795, 39.8283],
    ];
    onSave({ organizationId, name, type, description, coordinates, active: true, alertOnEntry, alertOnExit });
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-md w-full">
        <div className="p-6 border-b"><h3 className="text-lg font-semibold">Create Geofence</h3></div>
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" required />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
            <select value={type} onChange={(e) => setType(e.target.value as Geofence['type'])} className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent">
              <option value="allowed">Allowed Zone</option>
              <option value="restricted">Restricted Zone</option>
              <option value="customer">Customer Location</option>
              <option value="depot">Depot</option>
              <option value="service">Service Area</option>
              <option value="parking">Parking Zone</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea value={description} onChange={(e) => setDescription(e.target.value)} className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" rows={3} />
          </div>
          <div className="space-y-2">
            <label className="flex items-center gap-2"><input type="checkbox" checked={alertOnEntry} onChange={(e) => setAlertOnEntry(e.target.checked)} className="rounded" /><span className="text-sm text-gray-700">Alert on entry</span></label>
            <label className="flex items-center gap-2"><input type="checkbox" checked={alertOnExit} onChange={(e) => setAlertOnExit(e.target.checked)} className="rounded" /><span className="text-sm text-gray-700">Alert on exit</span></label>
          </div>
          <div className="flex gap-3 pt-4">
            <button type="button" onClick={onCancel} className="flex-1 px-4 py-2 border rounded-lg hover:bg-gray-50">Cancel</button>
            <button type="submit" className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">Create</button>
          </div>
        </form>
      </div>
    </div>
  );
}
