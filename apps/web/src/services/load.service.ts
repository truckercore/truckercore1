import { Load, LoadStop, ProofOfDelivery, LoadAcceptanceRequest } from '@/types/load.types';
import { v4 as uuidv4 } from 'uuid';

export class LoadService {
  /**
   * Accept a load offer
   */
  static async acceptLoad(request: LoadAcceptanceRequest): Promise<Load> {
    const response = await fetch('/api/driver/loads/accept', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error('Failed to accept load');
    }

    return response.json();
  }

  /**
   * Reject a load offer
   */
  static async rejectLoad(loadId: string, reason?: string): Promise<void> {
    const response = await fetch('/api/driver/loads/reject', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ loadId, reason }),
    });

    if (!response.ok) {
      throw new Error('Failed to reject load');
    }
  }

  /**
   * Update stop status
   */
  static async updateStopStatus(
    loadId: string,
    stopId: string,
    status: LoadStop['status'],
    timestamp: Date = new Date()
  ): Promise<Load> {
    const response = await fetch(`/api/driver/loads/${loadId}/stops/${stopId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status, timestamp }),
    });

    if (!response.ok) {
      throw new Error('Failed to update stop status');
    }

    return response.json();
  }

  /**
   * Submit proof of delivery
   */
  static async submitProofOfDelivery(
    loadId: string,
    stopId: string,
    pod: Omit<ProofOfDelivery, 'id' | 'stopId'>
  ): Promise<ProofOfDelivery> {
    const podData: ProofOfDelivery = {
      id: uuidv4(),
      stopId,
      ...pod,
    };

    const response = await fetch(`/api/driver/loads/${loadId}/stops/${stopId}/pod`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(podData),
    });

    if (!response.ok) {
      throw new Error('Failed to submit proof of delivery');
    }

    return response.json();
  }

  /**
   * Get next stop for a load
   */
  static getNextStop(load: Load): LoadStop | null {
    const pendingStops = load.stops
      .filter(stop => stop.status === 'pending')
      .sort((a, b) => a.sequence - b.sequence);

    return pendingStops[0] || null;
  }

  /**
   * Get current stop (arrived but not completed)
   */
  static getCurrentStop(load: Load): LoadStop | null {
    return load.stops.find(stop => stop.status === 'arrived') || null;
  }

  /**
   * Check if all stops are completed
   */
  static areAllStopsCompleted(load: Load): boolean {
    return load.stops.every(stop => 
      stop.status === 'completed' || stop.status === 'skipped'
    );
  }

  /**
   * Calculate load progress percentage
   */
  static calculateProgress(load: Load): number {
    const completed = load.stops.filter(
      stop => stop.status === 'completed' || stop.status === 'skipped'
    ).length;
    
    return (completed / load.stops.length) * 100;
  }

  /**
   * Capture photo for POD
   */
  static async capturePhoto(caption?: string): Promise<{
    id: string;
    dataUrl: string;
    caption?: string;
    timestamp: Date;
  }> {
    return new Promise((resolve, reject) => {
      if (typeof document === 'undefined') {
        reject(new Error('Not in a browser context'));
        return;
      }

      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*';
      // @ts-ignore capture is a known mobile attribute
      input.capture = 'environment';

      input.onchange = async (e) => {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (!file) {
          reject(new Error('No file selected'));
          return;
        }

        try {
          const dataUrl = await this.fileToDataUrl(file);
          resolve({
            id: uuidv4(),
            dataUrl,
            caption,
            timestamp: new Date(),
          });
        } catch (error) {
          reject(error);
        }
      };

      input.click();
    });
  }

  /**
   * Convert file to data URL
   */
  private static fileToDataUrl(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  /**
   * Format stop address
   */
  static formatStopAddress(stop: LoadStop): string {
    const { location } = stop;
    return `${location.address}, ${location.city}, ${location.state} ${location.zip}`;
  }

  /**
   * Get estimated time of arrival
   */
  static getEstimatedArrival(stop: LoadStop, currentLocation?: GeolocationCoordinates): Date | null {
    if (!currentLocation || !stop.location.latitude || !stop.location.longitude) {
      return stop.scheduledTime;
    }

    // Simplified ETA calculation - in production, use a routing API
    const distance = this.calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      stop.location.latitude,
      stop.location.longitude
    );

    // Assume average speed of 50 mph
    const hoursToArrival = distance / 50;
    const eta = new Date();
    eta.setTime(eta.getTime() + hoursToArrival * 3600 * 1000);

    return eta;
  }

  /**
   * Calculate distance between two points (Haversine formula)
   */
  private static calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
  ): number {
    const R = 3959; // Earth's radius in miles
    const dLat = this.toRad(lat2 - lat1);
    const dLon = this.toRad(lon2 - lon1);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) *
        Math.cos(this.toRad(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  private static toRad(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}
