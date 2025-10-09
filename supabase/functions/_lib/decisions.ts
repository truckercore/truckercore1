// functions/_lib/decisions.ts
// Runtime decisions loader for Deno Edge (Supabase)
// Precedence: DB (platform_decisions) → remote file (DECISIONS_URL, YAML) → env fallbacks

export type Decisions = {
  iam: {
    jwks_ttl: string; // e.g. "15m"
    invalidate_on: "any_signature_failure" | "kid_mismatch_only";
    scim: { bulk_deactivate_cap: number; dry_run_required: boolean };
    idp_health: { red_days: number; yellow_days: number };
  };
  ai: { ranking: { sample_rate: number; required_factors: string[] } };
};

const mem = new Map<string, { ts: number; val: Decisions }>();
const TTL_MS = 60_000; // 1 minute cache

// Lightweight dynamic import wrappers to avoid bundler issues
async function supabaseClient() {
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.46.1");
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, key, { auth: { persistSession: false } });
}

export async function loadDecisions(org_id?: string): Promise<Decisions> {
  const k = org_id ?? "global";
  const hit = mem.get(k);
  if (hit && Date.now() - hit.ts < TTL_MS) return hit.val;

  // 1) DB overrides (platform_decisions)
  let dbConfig: any = undefined;
  try {
    const sb = await supabaseClient();
    const { data: row } = await sb
      .from("platform_decisions")
      .select("config")
      .eq("org_id", org_id ?? null)
      .maybeSingle();
    dbConfig = row?.config;
  } catch (_) {
    // ignore db fetch issues; we'll fall back
  }

  // 2) File default (optional)
  let base: Decisions | null = null;
  const fileUrl = Deno.env.get("DECISIONS_URL") || "";
  if (fileUrl) {
    try {
      const resp = await fetch(fileUrl);
      if (resp.ok) {
        const txt = await resp.text();
        const { default: yaml } = await import("https://esm.sh/js-yaml@4.1.0");
        base = yaml.load(txt) as Decisions;
      }
    } catch (_) {
      // ignore fetch/parse issues
    }
  }

  // 3) Env fallback (minimal)
  const fallback: Decisions = {
    iam: {
      jwks_ttl: Deno.env.get("JWKS_TTL") ?? "15m",
      invalidate_on: (Deno.env.get("JWKS_INVALIDATE") as any) ?? "any_signature_failure",
      scim: {
        bulk_deactivate_cap: Number(Deno.env.get("SCIM_BULK_CAP") ?? "100"),
        dry_run_required: (Deno.env.get("SCIM_DRY_RUN") ?? "true") === "true",
      },
      idp_health: {
        red_days: Number(Deno.env.get("IDP_RED_DAYS") ?? "7"),
        yellow_days: Number(Deno.env.get("IDP_YELLOW_DAYS") ?? "21"),
      },
    },
    ai: {
      ranking: {
        sample_rate: Number(Deno.env.get("AI_RANK_SAMPLE") ?? "0.1"),
        required_factors: (Deno.env.get("AI_RANK_FACTORS") ?? "distance,price,fuel").split(",").map(s=>s.trim()).filter(Boolean),
      },
    },
  };

  const decided = deepMerge<Decisions>(base ?? fallback, dbConfig ?? {});
  mem.set(k, { ts: Date.now(), val: decided });
  return decided;
}

export function deepMerge<T>(a: any, b: any): T {
  if (b === null || b === undefined) return a as T;
  if (a === null || a === undefined) return b as T;
  if (Array.isArray(a) && Array.isArray(b)) return b as T; // replace arrays
  if (typeof a === "object" && typeof b === "object") {
    const out: any = { ...a };
    for (const k of Object.keys(b)) out[k] = deepMerge(a[k], b[k]);
    return out as T;
  }
  return b as T;
}

// helpers for TTL strings like "15m"
export function toMs(s: string) {
  const m = /^(\d+)(ms|s|m|h)$/.exec(s);
  if (!m) throw new Error("invalid_duration");
  const n = +m[1];
  const unit = m[2];
  switch (unit) {
    case "ms": return n;
    case "s": return n * 1e3;
    case "m": return n * 6e4;
    case "h": return n * 36e5;
    default: return n;
  }
}
