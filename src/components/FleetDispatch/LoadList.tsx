import React from 'react';
import { Load } from '../../types';

interface LoadListProps {
  loads: Load[];
  onAssign: (load: Load) => void;
}

const LoadList: React.FC<LoadListProps> = ({ loads, onAssign }) => {
  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getStatusBadge = (status: string) => {
    const statusColors: { [key: string]: string } = {
      posted: 'status-posted',
      assigned: 'status-assigned',
      'in-transit': 'status-transit',
      delivered: 'status-delivered',
      cancelled: 'status-cancelled',
    };
    return statusColors[status] || 'status-default';
  };

  return (
    <div className="load-list">
      {loads.length === 0 ? (
        <div className="empty-state">
          <p>No loads found matching your criteria</p>
        </div>
      ) : (
        loads.map((load) => (
          <div key={load.id} className="load-card">
            <div className="load-header">
              <div>
                <h3>{load.loadNumber}</h3>
                <span className={`status-badge ${getStatusBadge(load.status)}`}>
                  {load.status.toUpperCase()}
                </span>
              </div>
              <div className="load-rate">${load.rate.toLocaleString()}</div>
            </div>

            <div className="load-route">
              <div className="route-point">
                <span className="route-icon origin">📍</span>
                <div className="route-details">
                  <strong>
                    {load.origin.city}, {load.origin.state}
                  </strong>
                  <small>{formatDate(load.pickupDate)}</small>
                </div>
              </div>
              <div className="route-arrow">→</div>
              <div className="route-point">
                <span className="route-icon destination">🎯</span>
                <div className="route-details">
                  <strong>
                    {load.destination.city}, {load.destination.state}
                  </strong>
                  <small>{formatDate(load.deliveryDate)}</small>
                </div>
              </div>
            </div>

            <div className="load-details">
              <div className="detail-item">
                <span className="detail-label">Cargo:</span>
                <span>{load.cargo.description}</span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Weight:</span>
                <span>{load.cargo.weight.toLocaleString()} lbs</span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Distance:</span>
                <span>{load.distance} mi</span>
              </div>
              <div className="detail-item">
                <span className="detail-label">Pieces:</span>
                <span>{load.cargo.pieces}</span>
              </div>
            </div>

            {load.requirements && load.requirements.length > 0 && (
              <div className="load-requirements">
                {load.requirements.map((req, index) => (
                  <span key={index} className="requirement-tag">
                    {req}
                  </span>
                ))}
              </div>
            )}

            {load.status === 'posted' && (
              <button className="assign-button" onClick={() => onAssign(load)}>
                Assign Driver
              </button>
            )}

            {load.assignedDriver && (
              <div className="assignment-info">
                <span>Assigned to Driver: {load.assignedDriver}</span>
              </div>
            )}
          </div>
        ))
      )}
    </div>
  );
};

export default LoadList;
