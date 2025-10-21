import { getSupabaseClient } from '@/lib/supabase/supabase-client';
import type { Load, LoadStop } from '@/types/load.types';
import { mockDataStore } from '@/lib/api/mock-store';

const USE_MOCK = process.env.USE_MOCK_DATA === 'true';

export class LoadRepository {
  /**
   * Get load by ID with stops
   */
  static async getById(loadId: string): Promise<Load | null> {
    if (USE_MOCK) {
      const load = mockDataStore.loads.find(l => l.id === loadId);
      return load || null;
    }

    const supabase = getSupabaseClient();
    const { data: loadData, error: loadError } = await supabase
      .from('loads')
      .select('*')
      .eq('id', loadId)
      .single();

    if (loadError) {
      // PGRST116 no rows
      if ((loadError as any).code === 'PGRST116') return null;
      throw new Error(`Failed to fetch load: ${loadError.message}`);
    }

    const { data: stopsData, error: stopsError } = await supabase
      .from('load_stops')
      .select('*')
      .eq('load_id', loadId)
      .order('sequence');

    if (stopsError) {
      throw new Error(`Failed to fetch stops: ${stopsError.message}`);
    }

    return this.mapFromDatabase(loadData, stopsData || []);
  }

  /**
   * Get active load for driver
   */
  static async getActiveLoad(driverId: string): Promise<Load | null> {
    if (USE_MOCK) {
      const load = mockDataStore.loads.find(
        l => l.driverId === driverId && 
             ['accepted', 'in_transit', 'at_pickup', 'picked_up', 'at_delivery'].includes(l.status as any)
      );
      return load || null;
    }

    const supabase = getSupabaseClient();
    const { data: loadData, error: loadError } = await supabase
      .from('loads')
      .select('*')
      .eq('driver_id', driverId)
      .in('status', ['accepted', 'in_transit', 'at_pickup', 'picked_up', 'at_delivery'])
      .order('accepted_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (loadError) {
      throw new Error(`Failed to fetch active load: ${loadError.message}`);
    }

    if (!loadData) return null;

    const { data: stopsData, error: stopsError } = await supabase
      .from('load_stops')
      .select('*')
      .eq('load_id', loadData.id)
      .order('sequence');

    if (stopsError) {
      throw new Error(`Failed to fetch stops: ${stopsError.message}`);
    }

    return this.mapFromDatabase(loadData, stopsData || []);
  }

  /**
   * Get available loads
   */
  static async getAvailableLoads(page: number = 1, limit: number = 20): Promise<{
    loads: Load[];
    total: number;
  }> {
    if (USE_MOCK) {
      const availableLoads = mockDataStore.loads.filter(l => l.status === 'offered');
      const start = (page - 1) * limit;
      return {
        loads: availableLoads.slice(start, start + limit),
        total: availableLoads.length,
      };
    }

    const supabase = getSupabaseClient();
    
    const { count, error: countError } = await supabase
      .from('loads')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'offered');

    if (countError) {
      throw new Error(`Failed to count available loads: ${countError.message}`);
    }

    const { data: loadsData, error: loadsError } = await supabase
      .from('loads')
      .select('*')
      .eq('status', 'offered')
      .order('offered_at', { ascending: false })
      .range((page - 1) * limit, page * limit - 1);

    if (loadsError) {
      throw new Error(`Failed to fetch available loads: ${loadsError.message}`);
    }

    const loads = await Promise.all(
      (loadsData || []).map(async (loadData) => {
        const { data: stopsData } = await supabase
          .from('load_stops')
          .select('*')
          .eq('load_id', loadData.id)
          .order('sequence');

        return this.mapFromDatabase(loadData, stopsData || []);
      })
    );

    return {
      loads,
      total: count || 0,
    };
  }

  /**
   * Update load
   */
  static async update(loadId: string, updates: Partial<Load>): Promise<Load> {
    if (USE_MOCK) {
      const load = mockDataStore.loads.find(l => l.id === loadId);
      if (!load) {
        throw new Error('Load not found');
      }
      Object.assign(load, updates, { updatedAt: new Date() });
      return load;
    }

    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('loads')
      .update({
        status: updates.status as string | undefined,
        driver_id: updates.driverId || null,
        accepted_at: updates.acceptedAt ? updates.acceptedAt.toISOString() : null,
        started_at: updates.startedAt ? updates.startedAt.toISOString() : null,
        completed_at: updates.completedAt ? updates.completedAt.toISOString() : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', loadId)
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to update load: ${error.message}`);
    }

    const { data: stopsData } = await supabase
      .from('load_stops')
      .select('*')
      .eq('load_id', loadId)
      .order('sequence');

    return this.mapFromDatabase(data, stopsData || []);
  }

  /**
   * Update stop
   */
  static async updateStop(
    stopId: string,
    updates: Partial<LoadStop>
  ): Promise<LoadStop> {
    if (USE_MOCK) {
      const load = mockDataStore.loads.find(l => 
        l.stops.some(s => s.id === stopId)
      );
      const stop = load?.stops.find(s => s.id === stopId);
      if (!stop) {
        throw new Error('Stop not found');
      }
      Object.assign(stop, updates);
      return stop;
    }

    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('load_stops')
      .update({
        status: updates.status as string | undefined,
        arrival_time: updates.arrivalTime ? updates.arrivalTime.toISOString() : null,
        departure_time: updates.departureTime ? updates.departureTime.toISOString() : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', stopId)
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to update stop: ${error.message}`);
    }

    return this.mapStopFromDatabase(data);
  }

  /**
   * Map database row to Load
   */
  private static mapFromDatabase(loadRow: any, stopsRows: any[]): Load {
    return {
      id: loadRow.id,
      loadNumber: loadRow.load_number,
      status: loadRow.status,
      driverId: loadRow.driver_id || undefined,
      stops: stopsRows.map(this.mapStopFromDatabase),
      totalDistance: loadRow.total_distance,
      estimatedDuration: loadRow.estimated_duration,
      cargo: {
        description: loadRow.cargo_description,
        weight: loadRow.cargo_weight,
        pieces: loadRow.cargo_pieces ?? undefined,
        hazmat: loadRow.hazmat,
      },
      rate: loadRow.rate,
      currency: loadRow.currency,
      specialInstructions: loadRow.special_instructions ?? undefined,
      offeredAt: loadRow.offered_at ? new Date(loadRow.offered_at) : undefined,
      acceptedAt: loadRow.accepted_at ? new Date(loadRow.accepted_at) : undefined,
      startedAt: loadRow.started_at ? new Date(loadRow.started_at) : undefined,
      completedAt: loadRow.completed_at ? new Date(loadRow.completed_at) : undefined,
      createdAt: new Date(loadRow.created_at),
      updatedAt: new Date(loadRow.updated_at),
    };
  }

  /**
   * Map database row to LoadStop
   */
  private static mapStopFromDatabase(row: any): LoadStop {
    return {
      id: row.id,
      type: row.type,
      sequence: row.sequence,
      location: {
        name: row.location_name,
        address: row.location_address,
        city: row.location_city,
        state: row.location_state,
        zip: row.location_zip,
        latitude: row.location_lat ?? undefined,
        longitude: row.location_lng ?? undefined,
      },
      scheduledTime: new Date(row.scheduled_time),
      arrivalTime: row.arrival_time ? new Date(row.arrival_time) : undefined,
      departureTime: row.departure_time ? new Date(row.departure_time) : undefined,
      status: row.status,
      instructions: row.instructions ?? undefined,
      contactName: row.contact_name ?? undefined,
      contactPhone: row.contact_phone ?? undefined,
    } as LoadStop;
  }
}
