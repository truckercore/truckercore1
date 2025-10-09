import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { withApiShape, ok, err, reqId } from "../_shared/http.ts";
import { logInfo, logErr } from "../_shared/obs.ts";

function getEnv(name: string, fallback?: string) {
  return Deno.env.get(name) ?? (fallback ? Deno.env.get(fallback) : undefined);
}

const SUPABASE_URL = getEnv("SUPABASE_URL")!;
const ANON_KEY = getEnv("SUPABASE_ANON_KEY", "SUPABASE_ANON")!;
const SERVICE_KEY = getEnv("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SERVICE_ROLE")!;

// Dark-launch and version knobs
const DARK = (Deno.env.get('CATALOG_DARK') ?? 'false').toLowerCase() === 'true';
const VERSION = Number(Deno.env.get('CATALOG_VERSION') ?? 1);

function jsonHeaders(etag: string, items: number, cache: 'hit'|'reval'|'miss', extra: Record<string,string> = {}) {
  return {
    'Content-Type': 'application/json',
    'Content-Security-Policy': "default-src 'none'",
    'X-Content-Type-Options': 'nosniff',
    'ETag': etag,
    'Cache-Control': 'public, max-age=60, must-revalidate',
    'x-catalog-version': String(VERSION),
    'x-catalog-items': String(items),
    'x-cache': cache,
    ...extra,
  } as Record<string,string>;
}

async function sha1(s: string) {
  const d = new TextEncoder().encode(s);
  const h = await crypto.subtle.digest('SHA-1', d);
  return [...new Uint8Array(h)].map(x => x.toString(16).padStart(2, '0')).join('');
}

// Last-known-good fallback (in-memory)
let __LKG_BODY: string | null = null;
let __LKG_5XX: number = 0;

serve(withApiShape(async (req, { requestId }) => {
  const rid = requestId || reqId();
  try {
    const anon = createClient(SUPABASE_URL, ANON_KEY);
    const svc  = createClient(SUPABASE_URL, SERVICE_KEY);
    const url = new URL(req.url);
    const variant = url.searchParams.get("variant") ?? "A";
    const locale  = url.searchParams.get("locale")  ?? "en";
    const env     = Deno.env.get("CATALOG_ENV") ?? "prod";

    // Resolve org/user for rate-limit and org overrides
    const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "";
    let orgId: string | null = null;
    let userId: string | null = null;
    if (token) {
      const { data: userInfo } = await svc.auth.getUser(token);
      userId = userInfo?.user?.id ?? null as any;
      orgId = (userInfo?.user as any)?.app_metadata?.app_org_id ?? null;
    }

    // Rate-limit: per-user (fallback org) per minute (best-effort)
    try {
      const minute = new Date(); minute.setSeconds(0,0);
      const key = (userId ?? orgId) as string | null;
      if (key) {
        await svc.from('feature_catalog_rate').upsert({ user_id: key, minute: minute.toISOString(), hits: 0 }, { onConflict: 'user_id,minute' });
        const { data: cur } = await svc
          .from('feature_catalog_rate')
          .select('hits')
          .eq('user_id', key)
          .eq('minute', minute.toISOString())
          .single();
        const nextHits = (cur?.hits ?? 0) + 1;
        await svc
          .from('feature_catalog_rate')
          .update({ hits: nextHits })
          .eq('user_id', key)
          .eq('minute', minute.toISOString());
        const maxPerMin = Number(Deno.env.get('FEATURE_CATALOG_RPM') ?? '60');
        if (nextHits > maxPerMin) {
          console.log(`METRIC catalog_requests_total route="/feature_catalog" 1`);
          console.log(`METRIC catalog_http_429_total route="/feature_catalog" 1`);
          return err('rate_limited', 'rate_limited', rid, 429);
        }
      }
    } catch (_) { /* ignore */ }

    // Base rows from resolved view
    let { data: rows, error } = await anon.from("v_feature_catalog_resolved").select("*");
    if (error) {
      logErr("feature_catalog query error", { requestId: rid });
      return err("internal_error", error.message, rid, 500);
    }

    // Filter exact env/variant/locale from resolved set
    rows = (rows || []).filter((r: any) => r.env === env && r.variant === variant && r.locale === locale);

    // Apply org-specific overrides explicitly using service role when org is known
    if (orgId) {
      const { data: ov, error: ovErr } = await svc
        .from("feature_overrides")
        .select("key, price_id, headline, blurb, tier_override, active, updated_at")
        .eq("org_id", orgId)
        .eq("active", true);
      if (!ovErr && ov?.length) {
        const map = new Map(rows.map((r: any) => [r.key, r]));
        for (const o of ov) {
          const base = map.get(o.key);
          if (!base) continue;
          if (o.headline) base.headline = o.headline;
          if (o.blurb)    base.blurb = o.blurb;
          if (o.price_id) base.price_id = o.price_id;
          if (o.tier_override) base.tier = o.tier_override;
          (base as any).__ov_updated_at = o.updated_at;
        }
        rows = Array.from(map.values());
      }
    }

    // Compute freshness source_ts from presentations and overrides
    let latestTs: number | null = null;
    try {
      const { data: pmax } = await svc
        .from('feature_presentations')
        .select('updated_at')
        .eq('env', env)
        .eq('variant', variant)
        .eq('locale', locale)
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (pmax?.updated_at) latestTs = new Date(pmax.updated_at as any).getTime();
    } catch (_) { /* ignore */ }
    for (const r of rows as any[]) {
      const t = r.__ov_updated_at ? new Date(r.__ov_updated_at).getTime() : null;
      if (t && (!latestTs || t > latestTs)) latestTs = t;
    }
    const nowMs = Date.now();
    const ageSeconds = latestTs ? Math.max(0, Math.round((nowMs - latestTs) / 1000)) : 0;

    // Build body (dark-launch option returns minimal metadata)
    const itemsCount = rows?.length ?? 0;
    const bodyObj = DARK
      ? { version: VERSION, itemsCount, keys: (rows as any[]).map(r => r.key), tier: 'catalog' }
      : { items: rows };
    const body = JSON.stringify(bodyObj);

    // Strong ETag using weak validator as prefix (W/sha1)
    const etag = `"W/${await sha1(body)}"`;

    // Caching semantics
    const inm = req.headers.get('If-None-Match');
    if (inm && inm === etag) {
      // Metrics: request + revalidation
      console.log(`METRIC catalog_requests_total route="/feature_catalog" 1`);
      console.log(`METRIC catalog_cache_revalidated_total route="/feature_catalog" 1`);
      console.log(`METRIC etag_age_seconds route="/feature_catalog" value=${ageSeconds}`);
      return new Response(null, { status: 304, headers: jsonHeaders(etag, itemsCount, 'reval', { 'x-etag-age-seconds': String(ageSeconds) }) });
    }

    // Metrics: request + (treat as hit/served fresh payload)
    console.log(`METRIC catalog_requests_total route="/feature_catalog" 1`);
    console.log(`METRIC catalog_cache_hits_total route="/feature_catalog" 1`);
    console.log(`METRIC etag_age_seconds route="/feature_catalog" value=${ageSeconds}`);

    // Refresh LKG on successful 200
    __LKG_BODY = body;
    __LKG_5XX = 0;

    logInfo("feature_catalog served", { requestId: rid, env, variant, locale, items: itemsCount, org_id: orgId ?? undefined });

    return new Response(body, { status: 200, headers: jsonHeaders(etag, itemsCount, 'hit', { 'x-etag-age-seconds': String(ageSeconds) }) });
  } catch (e) {
    const rid2 = requestId || rid;
    const msg = (e && (e as any).message) || String(e);
    // Increment 5xx counter and consider LKG fallback
    __LKG_5XX = (__LKG_5XX || 0) + 1;
    const thr = Number(Deno.env.get('LKG_5XX_THRESHOLD') ?? '3');
    if (__LKG_BODY && __LKG_5XX >= thr) {
      // Serve last-known-good snapshot
      console.log(`METRIC catalog_requests_total route="/feature_catalog" 1`);
      console.log(`METRIC catalog_cache_mode_total mode="lkg" 1`);
      logWarn?.("feature_catalog LKG served", { requestId: rid2 } as any);
      return new Response(__LKG_BODY, {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'X-Content-Type-Options': 'nosniff',
          'x-lkg': 'true',
          'Cache-Control': 'no-store'
        }
      });
    }
    logErr("feature_catalog unexpected", { requestId: rid2 });
    return err("internal_error", msg, rid2, 500);
  }
}));