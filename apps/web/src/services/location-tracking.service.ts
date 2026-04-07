import { v4 as uuidv4 } from 'uuid';

export interface LocationUpdate {
  id: string;
  driverId: string;
  latitude: number;
  longitude: number;
  accuracy: number;
  altitude?: number;
  heading?: number;
  speed?: number;
  timestamp: Date;
  synced: boolean;
  offline: boolean;
}

export class LocationTrackingService {
  private static readonly STORAGE_KEY = 'offline_locations';
  private static readonly MAX_OFFLINE_LOCATIONS = 1000;
  private static watchId: number | null = null;
  private static isTracking = false;

  /**
   * Start location tracking with offline caching
   */
  static startTracking(driverId: string, onUpdate?: (location: LocationUpdate) => void): void {
    if (this.isTracking) {
      console.warn('Location tracking already active');
      return;
    }

    if (typeof navigator === 'undefined' || !('geolocation' in navigator)) {
      throw new Error('Geolocation not supported');
    }

    const options: PositionOptions = {
      enableHighAccuracy: true,
      timeout: 10000,
      maximumAge: 0,
    };

    this.watchId = navigator.geolocation.watchPosition(
      (position) => {
        const location: LocationUpdate = {
          id: uuidv4(),
          driverId,
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          altitude: position.coords.altitude ?? undefined,
          heading: position.coords.heading ?? undefined,
          speed: position.coords.speed ?? undefined,
          timestamp: new Date(position.timestamp),
          synced: false,
          offline: typeof navigator !== 'undefined' ? !navigator.onLine : true,
        };

        // Cache offline
        this.cacheLocation(location);

        // Attempt to sync
        if (typeof navigator !== 'undefined' && navigator.onLine) {
          this.syncLocation(location).catch(console.error);
        }

        // Callback
        onUpdate?.(location);
      },
      (error) => {
        console.error('Location error:', error);
      },
      options
    );

    this.isTracking = true;
  }

  /**
   * Stop location tracking
   */
  static stopTracking(): void {
    if (typeof navigator !== 'undefined' && this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId);
      this.watchId = null;
      this.isTracking = false;
    }
  }

  /**
   * Cache location offline
   */
  private static cacheLocation(location: LocationUpdate): void {
    try {
      const cached = this.getCachedLocations();
      cached.push(location);

      // Limit cache size
      if (cached.length > this.MAX_OFFLINE_LOCATIONS) {
        cached.shift();
      }

      if (typeof localStorage !== 'undefined') {
        localStorage.setItem(this.STORAGE_KEY, JSON.stringify(cached));
      }
    } catch (error) {
      console.error('Failed to cache location:', error);
    }
  }

  /**
   * Get cached locations
   */
  static getCachedLocations(): LocationUpdate[] {
    try {
      if (typeof localStorage === 'undefined') return [];
      const data = localStorage.getItem(this.STORAGE_KEY);
      if (!data) return [];

      const locations = JSON.parse(data);
      return locations.map((loc: any) => ({
        ...loc,
        timestamp: new Date(loc.timestamp),
      }));
    } catch (error) {
      console.error('Failed to get cached locations:', error);
      return [];
    }
  }

  /**
   * Sync single location to server
   */
  private static async syncLocation(location: LocationUpdate): Promise<void> {
    try {
      const response = await fetch('/api/driver/location', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(location),
      });

      if (response.ok) {
        location.synced = true;
        this.updateCachedLocation(location);
      }
    } catch (error) {
      console.error('Failed to sync location:', error);
    }
  }

  /**
   * Sync all cached locations
   */
  static async syncCachedLocations(): Promise<number> {
    const cached = this.getCachedLocations();
    const unsynced = cached.filter(loc => !loc.synced);

    if (unsynced.length === 0) return 0;

    let syncedCount = 0;

    for (const location of unsynced) {
      try {
        await this.syncLocation(location);
        syncedCount++;
      } catch (error) {
        console.error('Sync failed for location:', location.id);
      }
    }

    // Remove synced locations
    const remaining = cached.filter(loc => !loc.synced);
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(this.STORAGE_KEY, JSON.stringify(remaining));
    }

    return syncedCount;
  }

  /**
   * Update cached location
   */
  private static updateCachedLocation(location: LocationUpdate): void {
    try {
      const cached = this.getCachedLocations();
      const index = cached.findIndex(loc => loc.id === location.id);

      if (index >= 0) {
        cached[index] = location;
        if (typeof localStorage !== 'undefined') {
          localStorage.setItem(this.STORAGE_KEY, JSON.stringify(cached));
        }
      }
    } catch (error) {
      console.error('Failed to update cached location:', error);
    }
  }

  /**
   * Check if background location is supported
   */
  static async checkBackgroundLocationSupport(): Promise<{
    supported: boolean;
    permission: PermissionState | null;
    message: string;
  }> {
    // Check if geolocation is available
    if (typeof navigator === 'undefined' || !('geolocation' in navigator)) {
      return {
        supported: false,
        permission: null,
        message: 'Geolocation not supported in this browser',
      };
    }

    // Check permissions API
    if ('permissions' in navigator) {
      try {
        // @ts-expect-error TS lib may not include PermissionName union
        const result = await navigator.permissions.query({ name: 'geolocation' as PermissionName });
        return {
          supported: true,
          permission: result.state,
          message: result.state === 'granted' 
            ? 'Background location enabled' 
            : 'Location permission required',
        };
      } catch (error) {
        return {
          supported: true,
          permission: null,
          message: 'Unable to check permission status',
        };
      }
    }

    return {
      supported: true,
      permission: null,
      message: 'Location tracking available',
    };
  }

  /**
   * Get current position once
   */
  static async getCurrentPosition(): Promise<LocationUpdate> {
    return new Promise((resolve, reject) => {
      if (typeof navigator === 'undefined' || !('geolocation' in navigator)) {
        reject(new Error('Geolocation not supported'));
        return;
      }

      navigator.geolocation.getCurrentPosition(
        (position) => {
          resolve({
            id: uuidv4(),
            driverId: '', // To be filled by caller
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy,
            altitude: position.coords.altitude ?? undefined,
            heading: position.coords.heading ?? undefined,
            speed: position.coords.speed ?? undefined,
            timestamp: new Date(position.timestamp),
            synced: false,
            offline: typeof navigator !== 'undefined' ? !navigator.onLine : true,
          });
        },
        (error) => reject(error),
        { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
      );
    });
  }

  /**
   * Clear all cached locations
   */
  static clearCache(): void {
    if (typeof localStorage !== 'undefined') {
      localStorage.removeItem(this.STORAGE_KEY);
    }
  }

  /**
   * Get tracking status
   */
  static getTrackingStatus(): {
    isTracking: boolean;
    cachedCount: number;
    unsyncedCount: number;
  } {
    const cached = this.getCachedLocations();
    return {
      isTracking: this.isTracking,
      cachedCount: cached.length,
      unsyncedCount: cached.filter(loc => !loc.synced).length,
    };
  }
}
