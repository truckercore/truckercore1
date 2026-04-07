import axios, { AxiosInstance } from 'axios';
import { ipcMain } from 'electron';

/**
 * DAT Load Board API Integration
 * Docs: https://developer.dat.com/
 *
 * Features:
 * - Search available loads
 * - Post loads
 * - Get rate analytics
 * - Search carriers
 */

interface DATConfig {
  apiKey: string;
  customerId: string;
  baseURL: string;
}

interface DATLoad {
  loadId: string;
  origin: {
    city: string;
    state: string;
    zip: string;
    latitude: number;
    longitude: number;
  };
  destination: {
    city: string;
    state: string;
    zip: string;
    latitude: number;
    longitude: number;
  };
  equipment: string;
  rate: number;
  miles: number;
  weight: number;
  commodity: string;
  pickupDate: string;
  deliveryDate: string;
  postedDate: string;
  company: string;
  contact: string;
}

interface DATRateAnalysis {
  averageRate: number;
  highRate: number;
  lowRate: number;
  loadCount: number;
  ratePerMile: number;
  trend: 'up' | 'down' | 'stable';
}

export class DATIntegration {
  private client: AxiosInstance;
  private config: DATConfig;

  constructor(config: DATConfig) {
    this.config = config;

    this.client = axios.create({
      baseURL: config.baseURL || 'https://freight.api.dat.com/v2',
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json',
        'X-Customer-Id': config.customerId,
      },
      timeout: 30000,
    });

    this.setupHandlers();
  }

  private setupHandlers() {
    // Search loads
    ipcMain.handle('dat:search-loads', async (_event, params: {
      origin: string;
      destination?: string;
      equipment: string;
      radius?: number;
      maxAge?: number; // hours
    }) => {
      return await this.searchLoads(params);
    });

    // Post load
    ipcMain.handle('dat:post-load', async (_event, load: any) => {
      return await this.postLoad(load);
    });

    // Get rate analysis
    ipcMain.handle('dat:get-rate-analysis', async (_event, params: {
      origin: string;
      destination: string;
      equipment: string;
    }) => {
      return await this.getRateAnalysis(params);
    });

    // Search carriers
    ipcMain.handle('dat:search-carriers', async (_event, params: {
      location: string;
      equipment: string;
      radius?: number;
    }) => {
      return await this.searchCarriers(params);
    });
  }

  async searchLoads(params: {
    origin: string;
    destination?: string;
    equipment: string;
    radius?: number;
    maxAge?: number;
  }): Promise<DATLoad[]> {
    try {
      const response = await this.client.get('/loads/search', {
        params: {
          origin: params.origin,
          destination: params.destination,
          equipmentType: params.equipment,
          originRadius: params.radius || 50,
          maxAge: params.maxAge || 24,
          sortBy: 'rate',
          sortOrder: 'desc',
          limit: 100,
        },
      });

      return this.transformDATLoads(response.data?.loads || []);
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('DAT search loads error:', error?.response?.data || error?.message);
      throw new Error(`Failed to search DAT loads: ${error?.message || 'unknown error'}`);
    }
  }

  async postLoad(load: {
    origin: { city: string; state: string; zip: string };
    destination: { city: string; state: string; zip: string };
    equipment: string;
    weight: number;
    length?: number;
    rate?: number;
    rateType?: 'flat' | 'perMile';
    pickupDate: string;
    deliveryDate: string;
    commodity: string;
    contact: { name: string; phone: string; email: string };
    specialRequirements?: string;
  }): Promise<{ success: boolean; loadId: string }> {
    try {
      const response = await this.client.post('/loads', {
        origin: {
          city: load.origin.city,
          state: load.origin.state,
          postalCode: load.origin.zip,
        },
        destination: {
          city: load.destination.city,
          state: load.destination.state,
          postalCode: load.destination.zip,
        },
        equipmentType: load.equipment,
        weight: load.weight,
        length: load.length,
        rate: load.rate,
        rateType: load.rateType || 'flat',
        earliestAvailability: load.pickupDate,
        latestAvailability: load.deliveryDate,
        commodity: load.commodity,
        comments: load.specialRequirements,
        contact: {
          name: load.contact.name,
          phone: load.contact.phone,
          email: load.contact.email,
        },
      });

      return {
        success: true,
        loadId: response.data?.loadId,
      };
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('DAT post load error:', error?.response?.data || error?.message);
      throw new Error(`Failed to post load to DAT: ${error?.message || 'unknown error'}`);
    }
  }

  async getRateAnalysis(params: {
    origin: string;
    destination: string;
    equipment: string;
  }): Promise<DATRateAnalysis> {
    try {
      const response = await this.client.get('/analytics/rates', {
        params: {
          origin: params.origin,
          destination: params.destination,
          equipmentType: params.equipment,
          period: 'last30days',
        },
      });

      const data = response.data || {};

      return {
        averageRate: data.averageLinehaul || 0,
        highRate: data.highLinehaul || 0,
        lowRate: data.lowLinehaul || 0,
        loadCount: data.loadCount || 0,
        ratePerMile: data.averageRatePerMile || 0,
        trend: this.calculateTrend(data.historicalRates || []),
      };
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('DAT rate analysis error:', error?.response?.data || error?.message);
      throw new Error(`Failed to get rate analysis: ${error?.message || 'unknown error'}`);
    }
  }

  async searchCarriers(params: {
    location: string;
    equipment: string;
    radius?: number;
  }): Promise<any[]> {
    try {
      const response = await this.client.get('/carriers/search', {
        params: {
          location: params.location,
          equipmentType: params.equipment,
          radius: params.radius || 100,
          limit: 50,
        },
      });

      return response.data?.carriers || [];
    } catch (error: any) {
      // eslint-disable-next-line no-console
      console.error('DAT search carriers error:', error?.response?.data || error?.message);
      throw new Error(`Failed to search carriers: ${error?.message || 'unknown error'}`);
    }
  }

  private transformDATLoads(loads: any[]): DATLoad[] {
    return loads.map((load: any) => ({
      loadId: load.id,
      origin: {
        city: load.origin?.city,
        state: load.origin?.state,
        zip: load.origin?.postalCode,
        latitude: load.origin?.latitude,
        longitude: load.origin?.longitude,
      },
      destination: {
        city: load.destination?.city,
        state: load.destination?.state,
        zip: load.destination?.postalCode,
        latitude: load.destination?.latitude,
        longitude: load.destination?.longitude,
      },
      equipment: load.equipmentType,
      rate: load.rate,
      miles: load.tripMiles,
      weight: load.weight,
      commodity: load.commodity,
      pickupDate: load.earliestAvailability,
      deliveryDate: load.latestAvailability,
      postedDate: load.postedDate,
      company: load.company?.name || 'Unknown',
      contact: load.contact?.phone || '',
    }));
  }

  private calculateTrend(historicalRates: number[]): 'up' | 'down' | 'stable' {
    if (!historicalRates || historicalRates.length < 2) return 'stable';

    const n = historicalRates.length;
    const recent = historicalRates.slice(Math.max(0, n - 5));
    const older = historicalRates.slice(0, Math.min(5, n));

    const avg = (arr: number[]) => (arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : 0);
    const recentAvg = avg(recent);
    const olderAvg = avg(older);

    if (olderAvg === 0) return 'stable';
    const change = ((recentAvg - olderAvg) / olderAvg) * 100;

    if (change > 5) return 'up';
    if (change < -5) return 'down';
    return 'stable';
  }
}
