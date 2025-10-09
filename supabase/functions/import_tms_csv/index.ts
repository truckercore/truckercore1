import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { parse } from "https://deno.land/std@0.224.0/csv/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON_KEY) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type TmsRow = {
  ref_number: string;
  pickup_at?: string;
  delivery_at?: string;
  billable_amount_cents?: string | number;
};

Deno.serve(async (req) => {
  const t0 = Date.now();
  const authHeader = req.headers.get("Authorization") ?? "";

  const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } });
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  try {
    const { data: ures, error: uerr } = await userClient.auth.getUser();
    if (uerr || !ures?.user) return new Response("Unauthorized", { status: 401 });

    const { data: prof, error: perr } = await userClient.from("profiles").select("org_id").eq("user_id", ures.user.id).single();
    if (perr) return new Response("Profile lookup failed", { status: 400 });
    const org_id = (prof as any)?.org_id;
    if (!org_id) return new Response("No org", { status: 400 });

    // Read CSV (multipart or URL)
    let csvText = "";
    const ctype = req.headers.get("content-type") ?? "";
    if (ctype.includes("multipart/form-data")) {
      const form = await req.formData();
      const file = form.get("file");
      if (!(file instanceof File)) return new Response("file missing", { status: 400 });
      csvText = await file.text();
    } else {
      const body = await req.json().catch(() => ({} as any));
      const url = body.url as string | undefined;
      if (!url) return new Response("url missing", { status: 400 });
      const r = await fetch(url);
      if (!r.ok) return new Response(`fetch failed: ${r.status}`, { status: 400 });
      csvText = await r.text();
    }

    // Normalize BOM
    csvText = csvText.replace(/^\uFEFF/, "");

    // Parse CSV to objects and validate headers
    const parsed = parse(csvText, { columns: true }) as Array<Record<string, string>>;
    const headerSet = new Set(Object.keys(parsed[0] ?? {}));
    const required = ["ref_number", "pickup_at", "delivery_at", "billable_amount_cents"];
    const missing = required.filter((k) => !headerSet.has(k));
    if (missing.length) {
      return new Response(`missing headers: ${missing.join(",")}` , { status: 400 });
    }

    const rows: TmsRow[] = parsed
      .map((r) => ({
        ref_number: (r.ref_number ?? "").trim(),
        pickup_at: r.pickup_at?.trim(),
        delivery_at: r.delivery_at?.trim(),
        billable_amount_cents: r.billable_amount_cents?.trim(),
      }))
      .filter((r) => r.ref_number.length > 0);

    // Create run
    const { data: runRow, error: runErr } = await admin
      .from("connectors.connector_runs")
      .insert({ org_id, connector_type: "TMS", source: "csv" })
      .select("id")
      .single();
    if (runErr) return new Response("run create failed", { status: 500 });
    const run_id = (runRow as any).id as number;

    // Batch insert staging
    const batchSize = 500;
    let processed = 0;
    for (let i = 0; i < rows.length; i += batchSize) {
      const chunk = rows.slice(i, i + batchSize).map((r) => ({
        run_id,
        org_id,
        ref_number: r.ref_number,
        pickup_at: r.pickup_at ? new Date(r.pickup_at).toISOString() : null,
        delivery_at: r.delivery_at ? new Date(r.delivery_at).toISOString() : null,
        billable_amount_cents:
          r.billable_amount_cents != null
            ? Number(String(r.billable_amount_cents).replace(/[, ]/g, ""))
            : null,
        raw: r,
      }));
      const { error } = await admin.from("connectors.tms_staging_loads").insert(chunk);
      if (error) throw error;
      processed += chunk.length;
    }

    // Merge staging -> core
    const { data: merged, error: mergeErr } = await admin.rpc("fn_merge_tms_staging_to_core", { p_run_id: run_id });
    if (mergeErr) throw mergeErr;

    const dur = Date.now() - t0;
    await admin
      .from("connectors.connector_runs")
      .update({
        status: "success",
        finished_at: new Date().toISOString(),
        rows_processed: processed,
        duration_ms: dur,
      })
      .eq("id", run_id);

    return new Response(JSON.stringify({ run_id, processed, merged, ms: dur }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
