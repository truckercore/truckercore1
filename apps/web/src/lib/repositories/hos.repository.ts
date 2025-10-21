import { getSupabaseClient } from '@/lib/supabase/supabase-client';
import type { HOSEntry } from '@/types/hos.types';
import { mockDataStore } from '@/lib/api/mock-store';

const USE_MOCK = process.env.USE_MOCK_DATA === 'true';

export class HOSRepository {
  /**
   * Get HOS entries for driver
   */
  static async getEntries(
    driverId: string,
    startDate?: Date,
    endDate?: Date
  ): Promise<HOSEntry[]> {
    if (USE_MOCK) {
      let entries = mockDataStore.hosEntries.filter(e => e.driverId === driverId);
      
      if (startDate && endDate) {
        entries = entries.filter(e => {
          const entryDate = new Date(e.startTime);
          return entryDate >= startDate && entryDate <= endDate;
        });
      }
      
      return entries.map(this.mapToHOSEntry);
    }

    const supabase = getSupabaseClient();
    let query = supabase
      .from('hos_entries')
      .select('*')
      .eq('driver_id', driverId)
      .order('start_time', { ascending: false });

    if (startDate && endDate) {
      query = query
        .gte('start_time', startDate.toISOString())
        .lte('start_time', endDate.toISOString());
    }

    const { data, error } = await query;

    if (error) {
      throw new Error(`Failed to fetch HOS entries: ${error.message}`);
    }

    return (data || []).map(this.mapFromDatabase);
  }

  /**
   * Create new HOS entry
   */
  static async create(entry: Omit<HOSEntry, 'id' | 'createdAt' | 'updatedAt'>): Promise<HOSEntry> {
    if (USE_MOCK) {
      const newEntry: any = {
        id: crypto.randomUUID(),
        ...entry,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
      mockDataStore.hosEntries.push(newEntry);
      return this.mapToHOSEntry(newEntry);
    }

    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('hos_entries')
      .insert({
        driver_id: entry.driverId,
        status: entry.status,
        start_time: entry.startTime.toISOString(),
        location_lat: entry.location.latitude,
        location_lng: entry.location.longitude,
        location_address: entry.location.address || null,
        notes: entry.notes || null,
      })
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to create HOS entry: ${error.message}`);
    }

    return this.mapFromDatabase(data);
  }

  /**
   * Update HOS entry
   */
  static async update(
    id: string,
    updates: Partial<HOSEntry>
  ): Promise<HOSEntry> {
    if (USE_MOCK) {
      const entry = mockDataStore.hosEntries.find(e => e.id === id);
      if (!entry) {
        throw new Error('HOS entry not found');
      }
      Object.assign(entry, updates, { updatedAt: new Date() });
      return this.mapToHOSEntry(entry);
    }

    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('hos_entries')
      .update({
        end_time: updates.endTime ? updates.endTime.toISOString() : null,
        notes: updates.notes,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to update HOS entry: ${error.message}`);
    }

    return this.mapFromDatabase(data);
  }

  /**
   * Get current active entry for driver
   */
  static async getCurrentEntry(driverId: string): Promise<HOSEntry | null> {
    if (USE_MOCK) {
      const entry = mockDataStore.hosEntries.find(
        e => e.driverId === driverId && !e.endTime
      );
      return entry ? this.mapToHOSEntry(entry) : null;
    }

    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('hos_entries')
      .select('*')
      .eq('driver_id', driverId)
      .is('end_time', null)
      .order('start_time', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      // PostgREST no rows: sometimes code 'PGRST116', but maybeSingle avoids error for no rows
      throw new Error(`Failed to fetch current entry: ${error.message}`);
    }

    return data ? this.mapFromDatabase(data) : null;
  }

  /**
   * Map database row to HOSEntry
   */
  private static mapFromDatabase(row: any): HOSEntry {
    return {
      id: row.id,
      driverId: row.driver_id,
      status: row.status,
      startTime: new Date(row.start_time),
      endTime: row.end_time ? new Date(row.end_time) : undefined,
      location: {
        latitude: row.location_lat,
        longitude: row.location_lng,
        address: row.location_address || undefined,
      },
      odometer: row.odometer ?? undefined,
      engineHours: row.engine_hours ?? undefined,
      notes: row.notes ?? undefined,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }

  /**
   * Map mock entry to HOSEntry
   */
  private static mapToHOSEntry(entry: any): HOSEntry {
    return {
      id: entry.id,
      driverId: entry.driverId,
      status: entry.status,
      startTime: new Date(entry.startTime),
      endTime: entry.endTime ? new Date(entry.endTime) : undefined,
      location: entry.location,
      odometer: entry.odometer,
      engineHours: entry.engineHours,
      notes: entry.notes,
      createdAt: new Date(entry.createdAt),
      updatedAt: new Date(entry.updatedAt),
    };
  }
}
