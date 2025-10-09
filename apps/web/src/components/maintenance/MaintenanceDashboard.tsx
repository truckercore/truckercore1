import React, { useEffect, useState } from 'react';
import { maintenanceEngine } from '@/services/maintenance/MaintenanceEngine';
import type { MaintenanceDashboard as MD, WorkOrder, Vehicle } from '@/types/fleet.types';

export const MaintenanceDashboard: React.FC<{ fleetId: string }> = ({ fleetId }) => {
  const [dashboard, setDashboard] = useState<MD | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedWorkOrder, setSelectedWorkOrder] = useState<WorkOrder | null>(null);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      try {
        const data = await maintenanceEngine.getMaintenanceDashboard(fleetId);
        setDashboard(data);
      } finally {
        setLoading(false);
      }
    };
    void load();
    const id = setInterval(load, 60000);
    return () => clearInterval(id);
  }, [fleetId]);

  if (loading || !dashboard) return <div className="loading">Loading maintenance dashboard...</div>;

  return (
    <div className="maintenance-dashboard">
      <h2>🔧 Maintenance Dashboard</h2>

      <div className="maintenance-stats">
        <StatCard title="Total Vehicles" value={dashboard.summary.totalVehicles} icon="🚗" />
        <StatCard title="Pending Work Orders" value={dashboard.summary.pendingWorkOrders} icon="📋" color="orange" />
        <StatCard title="In Progress" value={dashboard.summary.inProgressWorkOrders} icon="🔧" color="blue" />
        <StatCard title="Due This Month" value={dashboard.summary.upcomingMaintenance} icon="⏰" color="red" />
        <StatCard title="Cost This Month" value={`$${dashboard.summary.totalCostThisMonth.toLocaleString()}`} icon="💰" color="green" />
      </div>

      <div className="upcoming-maintenance">
        <h3>Vehicles Due Soon</h3>
        {dashboard.vehiclesDueSoon.length === 0 ? (
          <div className="empty-state">No vehicles due for maintenance soon</div>
        ) : (
          <div className="vehicle-grid">
            {dashboard.vehiclesDueSoon.map(v => (
              <VehicleMaintenanceCard key={v.id} vehicle={v} />
            ))}
          </div>
        )}
      </div>

      <div className="work-orders">
        <h3>Recent Work Orders</h3>
        {dashboard.recentWorkOrders.length === 0 ? (
          <div className="empty-state">No recent work orders</div>
        ) : (
          <div className="work-order-list">
            {dashboard.recentWorkOrders.map(wo => (
              <WorkOrderCard key={wo.id} workOrder={wo} onClick={() => setSelectedWorkOrder(wo)} />
            ))}
          </div>
        )}
      </div>

      {selectedWorkOrder && (
        <WorkOrderModal
          workOrder={selectedWorkOrder}
          onClose={() => setSelectedWorkOrder(null)}
          onComplete={async () => {
            setSelectedWorkOrder(null);
            const data = await maintenanceEngine.getMaintenanceDashboard(fleetId);
            setDashboard(data);
          }}
        />
      )}
    </div>
  );
};

const VehicleMaintenanceCard: React.FC<{ vehicle: Vehicle }> = ({ vehicle }) => {
  const daysUntilDue = vehicle.nextMaintenance ? Math.floor((new Date(vehicle.nextMaintenance).getTime() - Date.now()) / (1000*60*60*24)) : null;
  return (
    <div className="vehicle-maintenance-card">
      <div className="vehicle-info">
        <h4>{vehicle.make} {vehicle.model}</h4>
        <div className="vehicle-details">
          <span>{vehicle.licensePlate}</span>
          <span>{vehicle.vin}</span>
        </div>
      </div>
      <div className="maintenance-info">
        {daysUntilDue !== null && (
          <div className={`days-due ${daysUntilDue < 3 ? 'urgent' : ''}`}>
            {daysUntilDue > 0 ? `Due in ${daysUntilDue} days` : `Overdue by ${Math.abs(daysUntilDue)} days`}
          </div>
        )}
        <div className="odometer">{(vehicle.odometer || 0).toLocaleString()} miles</div>
      </div>
    </div>
  );
};

const WorkOrderCard: React.FC<{ workOrder: WorkOrder; onClick: () => void; }> = ({ workOrder, onClick }) => {
  const statusColors: Record<string,string> = { pending: '#f59e0b', scheduled: '#3b82f6', in_progress: '#8b5cf6', completed: '#10b981', cancelled: '#6b7280' };
  return (
    <div className="work-order-card" onClick={onClick} style={{ borderLeftColor: statusColors[workOrder.status] }}>
      <div className="work-order-header">
        <span className={`status-badge status-${workOrder.status}`}>{workOrder.status.replace('_',' ').toUpperCase()}</span>
        <span className={`priority-badge priority-${workOrder.priority}`}>{workOrder.priority.toUpperCase()}</span>
      </div>
      <div className="work-order-details">
        <div className="tasks-count">{workOrder.tasks.length} task(s)</div>
        {workOrder.scheduledDate && <div className="scheduled-date">Scheduled: {new Date(workOrder.scheduledDate).toLocaleDateString()}</div>}
        {workOrder.cost && <div className="cost">${workOrder.cost.toLocaleString()}</div>}
      </div>
    </div>
  );
};

const WorkOrderModal: React.FC<{ workOrder: WorkOrder; onClose: () => void; onComplete: () => void; }> = ({ workOrder, onClose, onComplete }) => {
  const [completing, setCompleting] = useState(false);
  const [cost, setCost] = useState('');
  const [notes, setNotes] = useState('');

  const complete = async () => {
    setCompleting(true);
    try {
      await maintenanceEngine.completeWorkOrder(workOrder.id, { cost: parseFloat(cost) || 0, parts: [], labor: [], notes });
      onComplete();
    } finally {
      setCompleting(false);
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content work-order-modal" onClick={e => e.stopPropagation()}>
        <h3>Work Order Details</h3>
        <div className="modal-body">
          <div className="info-row"><label>Status:</label><span className={`status-badge status-${workOrder.status}`}>{workOrder.status.toUpperCase()}</span></div>
          <div className="info-row"><label>Priority:</label><span className={`priority-badge priority-${workOrder.priority}`}>{workOrder.priority.toUpperCase()}</span></div>
          {workOrder.scheduledDate && <div className="info-row"><label>Scheduled:</label><span>{new Date(workOrder.scheduledDate).toLocaleString()}</span></div>}
          <div className="tasks-section">
            <h4>Tasks</h4>
            {workOrder.tasks.map(t => (
              <div key={t.id} className="task-item">
                <div className="task-name">{t.name}</div>
                {t.description && <div className="task-description">{t.description}</div>}
                <div className="task-details"><span>{t.estimatedDuration} min</span>{t.estimatedCost && <span>${t.estimatedCost}</span>}</div>
              </div>
            ))}
          </div>
          {workOrder.status !== 'completed' && workOrder.status !== 'cancelled' && (
            <div className="completion-section">
              <h4>Complete Work Order</h4>
              <div className="form-group"><label>Total Cost</label><input type="number" value={cost} onChange={e => setCost(e.target.value)} placeholder="0.00" className="form-input" /></div>
              <div className="form-group"><label>Notes</label><textarea value={notes} onChange={e => setNotes(e.target.value)} placeholder="Work completed, parts replaced, etc." className="form-textarea" rows={4} /></div>
            </div>
          )}
        </div>
        <div className="modal-actions">
          <button onClick={onClose} className="btn btn-secondary">Close</button>
          {workOrder.status !== 'completed' && workOrder.status !== 'cancelled' && (
            <button onClick={complete} disabled={completing} className="btn btn-primary">{completing ? 'Completing...' : 'Complete Work Order'}</button>
          )}
        </div>
      </div>
    </div>
  );
};

const StatCard: React.FC<{ title: string; value: string | number; icon: string; color?: string; }> = ({ title, value, icon, color = 'blue' }) => (
  <div className="stat-card" style={{ borderColor: color }}>
    <div className="stat-icon">{icon}</div>
    <div className="stat-content">
      <div className="stat-title">{title}</div>
      <div className="stat-value">{value}</div>
    </div>
  </div>
);

export default MaintenanceDashboard;
