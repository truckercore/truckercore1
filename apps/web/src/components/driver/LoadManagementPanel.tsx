"use client";
import React, { useState } from 'react';
import { Load, LoadStop, ProofOfDelivery } from '@/types/load.types';
import { LoadService } from '@/services/load.service';
import { LocationUpdate } from '@/services/location-tracking.service';
import ProofOfDeliveryModal from './ProofOfDeliveryModal';

interface LoadManagementPanelProps {
  load: Load;
  currentLocation: LocationUpdate | null;
  onLoadUpdate: (load: Load) => void;
}

export default function LoadManagementPanel({
  load,
  currentLocation,
  onLoadUpdate,
}: LoadManagementPanelProps) {
  const [showPODModal, setShowPODModal] = useState(false);
  const [selectedStop, setSelectedStop] = useState<LoadStop | null>(null);

  const nextStop = LoadService.getNextStop(load);
  const currentStop = LoadService.getCurrentStop(load);
  const progress = LoadService.calculateProgress(load);

  const handleArriveAtStop = async (stop: LoadStop) => {
    try {
      const updatedLoad = await LoadService.updateStopStatus(
        load.id,
        stop.id,
        'arrived'
      );
      onLoadUpdate(updatedLoad);
    } catch (error) {
      console.error('Failed to update stop status:', error);
      alert('Failed to update status. Please try again.');
    }
  };

  const handleCompleteStop = (stop: LoadStop) => {
    setSelectedStop(stop);
    setShowPODModal(true);
  };

  const handleSubmitPOD = async (pod: Omit<ProofOfDelivery, 'id' | 'stopId'>) => {
    if (!selectedStop) return;

    try {
      await LoadService.submitProofOfDelivery(load.id, selectedStop.id, pod);
      
      const updatedLoad = await LoadService.updateStopStatus(
        load.id,
        selectedStop.id,
        'completed'
      );
      
      onLoadUpdate(updatedLoad);
      setShowPODModal(false);
      setSelectedStop(null);
    } catch (error) {
      console.error('Failed to submit POD:', error);
      alert('Failed to submit proof of delivery. Please try again.');
    }
  };

  return (
    <div className="load-panel">
      <h2>Active Load</h2>

      {/* Load Header */}
      <div className="load-header">
        <div className="load-number">#{load.loadNumber}</div>
        <div className="load-status">{load.status.replace('_', ' ')}</div>
      </div>

      {/* Progress Bar */}
      <div className="load-progress">
        <div className="progress-label">
          {Math.round(progress)}% Complete
        </div>
        <div className="progress-bar">
          <div 
            className="progress-bar-fill"
            style={{ width: `${progress}%` }}
          />
        </div>
      </div>

      {/* Cargo Info */}
      <div className="cargo-info">
        <h3>Cargo Details</h3>
        <div className="cargo-details">
          <div className="detail">
            <span className="label">Description:</span>
            <span className="value">{load.cargo.description}</span>
          </div>
          <div className="detail">
            <span className="label">Weight:</span>
            <span className="value">{load.cargo.weight.toLocaleString()} lbs</span>
          </div>
          {load.cargo.pieces && (
            <div className="detail">
              <span className="label">Pieces:</span>
              <span className="value">{load.cargo.pieces}</span>
            </div>
          )}
          {load.cargo.hazmat && (
            <div className="hazmat-badge">⚠️ HAZMAT</div>
          )}
        </div>
      </div>

      {/* Current/Next Stop */}
      {(currentStop || nextStop) && (
        <div className="current-stop">
          <h3>
            {currentStop ? 'Current Stop' : 'Next Stop'}
          </h3>
          {(() => {
            const stop = currentStop || nextStop!;
            const eta = currentLocation 
              ? LoadService.getEstimatedArrival(stop, currentLocation as any)
              : null;

            return (
              <div className="stop-card">
                <div className="stop-header">
                  <span className="stop-type">
                    {stop.type === 'pickup' ? '📦 Pickup' : '📍 Delivery'}
                  </span>
                  <span className="stop-sequence">
                    Stop {stop.sequence} of {load.stops.length}
                  </span>
                </div>

                <div className="stop-location">
                  <div className="location-name">{stop.location.name}</div>
                  <div className="location-address">
                    {LoadService.formatStopAddress(stop)}
                  </div>
                </div>

                <div className="stop-timing">
                  <div className="timing-item">
                    <span className="label">Scheduled:</span>
                    <span className="value">
                      {new Date(stop.scheduledTime).toLocaleString()}
                    </span>
                  </div>
                  {eta && (
                    <div className="timing-item">
                      <span className="label">ETA:</span>
                      <span className="value">
                        {eta.toLocaleTimeString()}
                      </span>
                    </div>
                  )}
                </div>

                {stop.instructions && (
                  <div className="stop-instructions">
                    <strong>Instructions:</strong> {stop.instructions}
                  </div>
                )}

                {stop.contactName && (
                  <div className="stop-contact">
                    <span className="icon">👤</span>
                    <span>{stop.contactName}</span>
                    {stop.contactPhone && (
                      <a href={`tel:${stop.contactPhone}`}>
                        📞 {stop.contactPhone}
                      </a>
                    )}
                  </div>
                )}

                <div className="stop-actions">
                  {stop.status === 'pending' && (
                    <button 
                      className="btn-primary"
                      onClick={() => handleArriveAtStop(stop)}
                    >
                      ✓ Arrive at Stop
                    </button>
                  )}
                  {stop.status === 'arrived' && (
                    <button 
                      className="btn-success"
                      onClick={() => handleCompleteStop(stop)}
                    >
                      📸 Complete {stop.type === 'pickup' ? 'Pickup' : 'Delivery'}
                    </button>
                  )}
                </div>
              </div>
            );
          })()}
        </div>
      )}

      {/* All Stops List */}
      <div className="stops-list">
        <h3>All Stops ({load.stops.length})</h3>
        <div className="stops-timeline">
          {load.stops.map((stop, index) => (
            <div 
              key={stop.id} 
              className={`timeline-stop ${stop.status}`}
            >
              <div className="timeline-marker">
                {stop.status === 'completed' ? '✓' : index + 1}
              </div>
              <div className="timeline-content">
                <div className="stop-name">
                  {stop.type === 'pickup' ? '📦' : '📍'} {stop.location.name}
                </div>
                <div className="stop-city">
                  {stop.location.city}, {stop.location.state}
                </div>
                <div className="stop-status-badge">{stop.status}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Special Instructions */}
      {load.specialInstructions && (
        <div className="special-instructions">
          <h3>⚠️ Special Instructions</h3>
          <p>{load.specialInstructions}</p>
        </div>
      )}

      {/* Proof of Delivery Modal */}
      {showPODModal && selectedStop && (
        <ProofOfDeliveryModal
          stop={selectedStop}
          onSubmit={handleSubmitPOD}
          onCancel={() => {
            setShowPODModal(false);
            setSelectedStop(null);
          }}
        />
      )}
    </div>
  );
}
