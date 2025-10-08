"use client";
import React from 'react';

interface OfflineModeIndicatorProps {
  isOnline: boolean;
}

export default function OfflineModeIndicator({ isOnline }: OfflineModeIndicatorProps) {
  return (
    <div className={`status-indicator ${isOnline ? 'online' : 'offline'}`}>
      <span className="indicator-dot" />
      <span className="indicator-text">
        {isOnline ? 'Online' : 'Offline Mode'}
      </span>
    </div>
  );
}
