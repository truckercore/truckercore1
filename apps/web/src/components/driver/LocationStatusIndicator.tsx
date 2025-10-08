"use client";
import React from 'react';
import { LocationUpdate } from '@/services/location-tracking.service';

interface LocationStatusIndicatorProps {
  isTracking: boolean;
  currentLocation: LocationUpdate | null;
}

export default function LocationStatusIndicator({
  isTracking,
  currentLocation,
}: LocationStatusIndicatorProps) {
  return (
    <div className={`status-indicator ${isTracking ? 'active' : 'inactive'}`}>
      <span className="indicator-icon">📍</span>
      <span className="indicator-text">
        {isTracking ? 'Location Active' : 'Location Inactive'}
      </span>
      {currentLocation && (
        <span className="accuracy-text">
          ±{Math.round(currentLocation.accuracy)}m
        </span>
      )}
    </div>
  );
}
