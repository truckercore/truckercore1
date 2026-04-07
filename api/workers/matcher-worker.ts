// matcher-worker.ts
import { db, publishEvent } from './shared';

type SavedSearch = {
  id: string; org_id: string; user_id: string; role: string; filters: any; is_active: boolean;
};

type Load = any;

export async function runMatchCycle(now = new Date()) {
  const searches: SavedSearch[] = await db.savedSearches.findActive();
  const windowStart = new Date(now.getTime() - 60_000); // last minute
  const freshLoads: Load[] = await db.loads.findSince(windowStart);

  for (const ss of searches) {
    const candidates = filterBy(ss.filters, freshLoads);
    for (const load of candidates) {
      const exists = await db.loadAlerts.exists(ss.user_id, (load as any).id);
      if (exists) continue;

      await db.loadAlerts.insert({
        org_id: ss.org_id,
        user_id: ss.user_id,
        saved_search_id: ss.id,
        match_type: 'load',
        match_payload: minimalPayload(load, ss.filters),
        load_id: (load as any).id,
        triggered_at: new Date().toISOString()
      });

      await publishEvent('alert.triggered', {
        org_id: ss.org_id,
        user_id: ss.user_id,
        kind: 'saved_search_match',
        load_id: (load as any).id
      });
    }
  }
}

function filterBy(filters: any, loads: any[]) {
  // Implement origin/destination/equipment/date windows, etc.
  return loads.filter(l => matches(l, filters));
}

function matches(_load: any, _filters: any) {
  // TODO: robust matcher
  return true;
}

function minimalPayload(load: any, _filters: any) {
  return { id: load.id, ref: load.ref, origin: load.origin, dest: load.dest, equipment: load.equipment };
}
