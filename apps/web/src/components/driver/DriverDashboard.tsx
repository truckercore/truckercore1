"use client";
import React, { useState, useEffect } from 'react';
import { HOSService } from '@/services/hos.service';
import { LocationTrackingService, LocationUpdate } from '@/services/location-tracking.service';
import { LoadService } from '@/services/load.service';
import { HOSLimits, HOSWarning, HOSEntry, HOSStatus } from '@/types/hos.types';
import { Load } from '@/types/load.types';
import HOSStatusPanel from './HOSStatusPanel';
import LoadManagementPanel from './LoadManagementPanel';
import LocationStatusIndicator from './LocationStatusIndicator';
import OfflineModeIndicator from './OfflineModeIndicator';

interface DriverDashboardProps {
  driverId: string;
}

export default function DriverDashboard({ driverId }: DriverDashboardProps) {
  const [hosEntries, setHosEntries] = useState<HOSEntry[]>([]);
  const [hosLimits, setHosLimits] = useState<HOSLimits | null>(null);
  const [hosWarnings, setHosWarnings] = useState<HOSWarning[]>([]);
  const [currentStatus, setCurrentStatus] = useState<HOSStatus>('off_duty');
  
  const [activeLoad, setActiveLoad] = useState<Load | null>(null);
  const [currentLocation, setCurrentLocation] = useState<LocationUpdate | null>(null);
  const [isOnline, setIsOnline] = useState(typeof navigator !== 'undefined' ? navigator.onLine : true);
  const [locationTracking, setLocationTracking] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  // Initialize
  useEffect(() => {
    loadInitialData();
    const cleanup = setupEventListeners();
    startLocationTracking();

    return () => {
      LocationTrackingService.stopTracking();
      cleanup?.();
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [driverId]);

  // Update HOS calculations when entries change
  useEffect(() => {
    if (hosEntries.length > 0) {
      const limits = HOSService.calculateHOSLimits(hosEntries);
      setHosLimits(limits);

      const warnings = HOSService.generateWarnings(limits, currentStatus);
      setHosWarnings(warnings);

      // Check for violations
      const violations = HOSService.detectViolations(hosEntries, limits);
      if (violations.length > 0) {
        handleViolations(violations);
      }
    }
  }, [hosEntries, currentStatus]);

  // Periodic updates
  useEffect(() => {
    const interval = setInterval(() => {
      if (isOnline) {
        syncOfflineData();
        refreshHOSData();
      }
    }, 60000); // Every minute

    return () => clearInterval(interval);
  }, [isOnline]);

  const loadInitialData = async () => {
    try {
      // Load HOS entries
      const response = await fetch(`/api/driver/${driverId}/hos`);
      if (response.ok) {
        const data = await response.json();
        setHosEntries((data.entries || []).map((e: any) => ({
          ...e,
          startTime: new Date(e.startTime),
          endTime: e.endTime ? new Date(e.endTime) : undefined,
          createdAt: new Date(e.createdAt),
          updatedAt: new Date(e.updatedAt),
        })));
        setCurrentStatus(data.currentStatus as HOSStatus);
      }

      // Load active load
      const loadResponse = await fetch(`/api/driver/${driverId}/active-load`);
      if (loadResponse.ok) {
        const load = await loadResponse.json();
        setActiveLoad(load);
      }
    } catch (error) {
      console.error('Failed to load initial data:', error);
    }
  };

  const setupEventListeners = () => {
    if (typeof window === 'undefined') return () => {};

    // Online/offline detection
    const handleOnline = () => {
      setIsOnline(true);
      syncOfflineData();
    };
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  };

  const startLocationTracking = () => {
    try {
      LocationTrackingService.startTracking(driverId, (location) => {
        setCurrentLocation(location);
      });
      setLocationTracking(true);
    } catch (e) {
      console.warn('Unable to start location tracking', e);
      setLocationTracking(false);
    }
  };

  const syncOfflineData = async () => {
    try {
      const syncedCount = await LocationTrackingService.syncCachedLocations();
      if (syncedCount > 0) {
        console.log(`Synced ${syncedCount} locations`);
      }
    } catch (error) {
      console.error('Failed to sync offline data:', error);
    }
  };

  const refreshHOSData = async () => {
    try {
      const response = await fetch(`/api/driver/${driverId}/hos`);
      if (response.ok) {
        const data = await response.json();
        setHosEntries((data.entries || []).map((e: any) => ({
          ...e,
          startTime: new Date(e.startTime),
          endTime: e.endTime ? new Date(e.endTime) : undefined,
          createdAt: new Date(e.createdAt),
          updatedAt: new Date(e.updatedAt),
        })));
      }
    } catch (error) {
      console.error('Failed to refresh HOS data:', error);
    }
  };

  const handleStatusChange = async (newStatus: HOSStatus) => {
    try {
      const location = await LocationTrackingService.getCurrentPosition();
      
      const response = await fetch(`/api/driver/${driverId}/hos/status`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: newStatus,
          location: {
            latitude: location.latitude,
            longitude: location.longitude,
          },
          timestamp: new Date(),
        }),
      });

      if (response.ok) {
        const newEntry = await response.json();
        setHosEntries([...hosEntries, {
          ...newEntry,
          startTime: new Date(newEntry.startTime),
          endTime: newEntry.endTime ? new Date(newEntry.endTime) : undefined,
          createdAt: new Date(newEntry.createdAt),
          updatedAt: new Date(newEntry.updatedAt),
        }]);
        setCurrentStatus(newStatus);
      }
    } catch (error) {
      console.error('Failed to change status:', error);
      alert('Failed to change status. Please try again.');
    }
  };

  const handleViolations = (violations: any[]) => {
    violations.forEach(violation => {
      if (violation.severity === 'violation') {
        // Show critical alert
        alert(`HOS VIOLATION: ${violation.message}`);
        
        // Log violation
        fetch(`/api/driver/${driverId}/hos/violations`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(violation),
        }).catch(console.error);
      }
    });
  };

  const handlePullToRefresh = async () => {
    setRefreshing(true);
    try {
      await loadInitialData();
      await syncOfflineData();
    } finally {
      setRefreshing(false);
    }
  };

  return (
    <div className="driver-dashboard">
      {/* Header */}
      <div className="dashboard-header">
        <h1>Driver Dashboard</h1>
        <div className="status-indicators">
          <OfflineModeIndicator isOnline={isOnline} />
          <LocationStatusIndicator 
            isTracking={locationTracking} 
            currentLocation={currentLocation}
          />
        </div>
      </div>

      {/* Pull to refresh hint */}
      <div className="refresh-hint">
        {refreshing ? 'Refreshing...' : '↓ Pull down to refresh'}
      </div>

      {/* HOS Status Panel */}
      <HOSStatusPanel
        limits={hosLimits}
        warnings={hosWarnings}
        currentStatus={currentStatus}
        onStatusChange={handleStatusChange}
      />

      {/* Active Load Panel */}
      {activeLoad && (
        <LoadManagementPanel
          load={activeLoad}
          currentLocation={currentLocation}
          onLoadUpdate={setActiveLoad}
        />
      )}

      {/* Quick Actions */}
      <div className="quick-actions">
        <button onClick={handlePullToRefresh} disabled={refreshing}>
          🔄 Refresh
        </button>
        <button onClick={() => {/* Navigate to loads */}}>
          📦 Available Loads
        </button>
        <button onClick={() => {/* Navigate to documents */}}>
          📄 Documents
        </button>
      </div>
    </div>
  );
}
