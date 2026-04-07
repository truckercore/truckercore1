// api/lib/entitlements.ts
// Entitlement helper with 5-minute in-memory cache and safe fallback.
export type Entitlement = { enabled: boolean; config?: any; source: 'user'|'org'|'plan'|'default' };

export type DbClient = {
  rpc: (fn: string, params: Record<string, any>) => { single: () => Promise<{ data: any; error?: any }> }
}

type CacheKey = string; // `${orgId}:${featureKey}:${userId ?? ''}`
const cache = new Map<CacheKey, { ent: Entitlement; ts: number }>();
const TTL_MS = 5 * 60 * 1000;

function key(orgId: string, featureKey: string, userId?: string | null): CacheKey {
  return `${orgId}:${featureKey}:${userId ?? ''}`;
}

export async function getEntitlement(db: DbClient, orgId: string, featureKey: string, userId?: string | null): Promise<Entitlement> {
  const k = key(orgId, featureKey, userId);
  const now = Date.now();
  const hit = cache.get(k);
  if (hit && now - hit.ts < TTL_MS) return hit.ent;

  try {
    const { data, error } = await db.rpc('get_entitlement', {
      p_org_id: orgId,
      p_feature_key: featureKey,
      p_user_id: userId ?? null,
    }).single();
    if (error || !data) {
      const ent: Entitlement = { enabled: false, source: 'default' };
      cache.set(k, { ent, ts: now });
      return ent;
    }
    const ent = data as Entitlement;
    cache.set(k, { ent, ts: now });
    return ent;
  } catch (_e) {
    const ent: Entitlement = { enabled: false, source: 'default' };
    cache.set(k, { ent, ts: now });
    return ent;
  }
}

// Optional audit hook; replace with real implementation if available
export type AuditFn = (args: { entity: string; entityId: string; action: string; meta?: any }) => Promise<void>;
export async function auditFeatureLocked(audit: AuditFn | undefined, featureKey: string, source: Entitlement['source'], endpoint: string) {
  try {
    if (!audit) return;
    await audit({ entity: 'entitlement', entityId: featureKey, action: 'feature_locked', meta: { source, endpoint } });
  } catch (_) { /* best-effort */ }
}
