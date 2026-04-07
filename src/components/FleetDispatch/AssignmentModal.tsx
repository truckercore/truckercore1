import React, { useState } from 'react';
import { Load, Driver, Truck, Assignment } from '../../types';

interface AssignmentModalProps {
  load: Load;
  drivers: Driver[];
  trucks: Truck[];
  onConfirm: (assignment: Assignment) => void;
  onCancel: () => void;
}

const AssignmentModal: React.FC<AssignmentModalProps> = ({ load, drivers, trucks, onConfirm, onCancel }) => {
  const [selectedDriver, setSelectedDriver] = useState('');
  const [selectedTruck, setSelectedTruck] = useState('');
  const [notes, setNotes] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!selectedDriver || !selectedTruck) {
      alert('Please select both a driver and a truck');
      return;
    }

    const assignment: Assignment = {
      loadId: load.id,
      driverId: selectedDriver,
      truckId: selectedTruck,
      assignedAt: new Date().toISOString(),
      assignedBy: 'current-dispatcher',
      notes: notes || undefined,
    };

    onConfirm(assignment);
  };

  const driver = drivers.find((d) => d.id === selectedDriver);
  const truck = trucks.find((t) => t.id === selectedTruck);

  return (
    <div className="modal-overlay" onClick={onCancel}>
      <div className="modal-content assignment-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Assign Load: {load.loadNumber}</h2>
          <button className="close-button" onClick={onCancel}>
            ×
          </button>
        </div>

        <div className="modal-body">
          <div className="load-summary">
            <h3>Load Details</h3>
            <div className="summary-grid">
              <div className="summary-item">
                <strong>Route:</strong>
                <span>
                  {load.origin.city}, {load.origin.state} → {load.destination.city}, {load.destination.state}
                </span>
              </div>
              <div className="summary-item">
                <strong>Distance:</strong>
                <span>{load.distance} miles</span>
              </div>
              <div className="summary-item">
                <strong>Weight:</strong>
                <span>{load.cargo.weight.toLocaleString()} lbs</span>
              </div>
              <div className="summary-item">
                <strong>Rate:</strong>
                <span>${load.rate.toLocaleString()}</span>
              </div>
            </div>
          </div>

          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label htmlFor="driver">Select Driver *</label>
              <select id="driver" value={selectedDriver} onChange={(e) => setSelectedDriver(e.target.value)} required>
                <option value="">-- Choose a driver --</option>
                {drivers.map((driver) => (
                  <option key={driver.id} value={driver.id}>
                    {driver.name} - {driver.currentLocation?.city}, {driver.currentLocation?.state} - {driver.hoursRemaining}h available
                  </option>
                ))}
              </select>
            </div>

            {driver && (
              <div className="selection-preview driver-preview">
                <h4>Selected Driver</h4>
                <p>
                  <strong>Name:</strong> {driver.name}
                </p>
                <p>
                  <strong>License:</strong> {driver.licenseNumber}
                </p>
                <p>
                  <strong>Phone:</strong> {driver.phone}
                </p>
                <p>
                  <strong>Location:</strong> {driver.currentLocation?.city}, {driver.currentLocation?.state}
                </p>
                <p>
                  <strong>Hours Available:</strong> {driver.hoursRemaining}
                </p>
              </div>
            )}

            <div className="form-group">
              <label htmlFor="truck">Select Truck *</label>
              <select id="truck" value={selectedTruck} onChange={(e) => setSelectedTruck(e.target.value)} required>
                <option value="">-- Choose a truck --</option>
                {trucks.map((truck) => (
                  <option key={truck.id} value={truck.id}>
                    {truck.truckNumber} - {truck.type} - {(truck.capacity / 1000).toFixed(0)}k lbs capacity
                  </option>
                ))}
              </select>
            </div>

            {truck && (
              <div className="selection-preview truck-preview">
                <h4>Selected Truck</h4>
                <p>
                  <strong>Number:</strong> {truck.truckNumber}
                </p>
                <p>
                  <strong>Type:</strong> {truck.type}
                </p>
                <p>
                  <strong>Capacity:</strong> {truck.capacity.toLocaleString()} lbs
                </p>
                <p>
                  <strong>Status:</strong> {truck.status}
                </p>
              </div>
            )}

            <div className="form-group">
              <label htmlFor="notes">Assignment Notes</label>
              <textarea
                id="notes"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={3}
                placeholder="Add any special instructions or notes for this assignment..."
              />
            </div>

            <div className="modal-actions">
              <button type="button" className="btn-secondary" onClick={onCancel}>
                Cancel
              </button>
              <button type="submit" className="btn-primary">
                Confirm Assignment
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default AssignmentModal;
