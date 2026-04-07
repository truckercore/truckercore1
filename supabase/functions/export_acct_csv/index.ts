import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON_KEY) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const EXPORT_BUCKET = Deno.env.get("EXPORT_BUCKET") ?? "exports";

function toCsv(rows: Array<Record<string, unknown>>): string {
  if (!rows.length) return "";
  const headers = Array.from(new Set(rows.flatMap(r => Object.keys(r))));
  const esc = (v: unknown) => {
    if (v === null || v === undefined) return "";
    const s = typeof v === "string" ? v : JSON.stringify(v);
    const needsQuote = /[",\n]/.test(s);
    return needsQuote ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const lines = [headers.join(",")];
  for (const r of rows) {
    lines.push(headers.map(h => esc((r as any)[h])).join(","));
  }
  return lines.join("\n");
}

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } });
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    const { data: ures } = await userClient.auth.getUser();
    const user = ures?.user;
    if (!user) return new Response("Unauthorized", { status: 401 });

    const { data: prof } = await userClient.from("profiles").select("org_id").eq("user_id", user.id).single();
    const org_id = (prof as any)?.org_id;
    if (!org_id) return new Response("No org", { status: 400 });

    const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
    const only_mismatches = Boolean(body.only_mismatches);

    // Find latest reconciliation result for this org
    const { data: latest } = await admin
      .from("connectors.recon_results")
      .select("id, tms_run_id, acct_run_id, created_at")
      .eq("org_id", org_id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!latest) return new Response("No recon results", { status: 404 });

    // Fetch lines for that recon
    const baseSel = admin
      .from("connectors.recon_lines")
      .select("ref_number, issue, tms_amount_cents, acct_amount_cents, acct_status")
      .eq("org_id", org_id)
      .eq("tms_run_id", (latest as any).tms_run_id)
      .eq("acct_run_id", (latest as any).acct_run_id);

    const { data: lines, error } = only_mismatches
      ? await baseSel.neq("issue", "matched") // lines we wrote only include mismatches/missing; keep as is
      : await baseSel;

    if (error) return new Response(error.message, { status: 500 });

    const rows = (lines ?? []).map((r: any) => ({
      ref_number: r.ref_number,
      issue: r.issue,
      tms_amount_cents: r.tms_amount_cents ?? '',
      acct_amount_cents: r.acct_amount_cents ?? '',
      acct_status: r.acct_status ?? '',
    }));

    const csv = toCsv(rows);
    const path = `${org_id}/recon_${(latest as any).id}_${Date.now()}.csv`;

    // Upload to Storage and sign URL
    const { error: upErr } = await admin.storage.from(EXPORT_BUCKET).upload(path, new Blob([csv], { type: 'text/csv' }), { upsert: true, contentType: 'text/csv' });
    if (upErr) return new Response(upErr.message, { status: 500 });

    const { data: signed, error: signErr } = await admin.storage.from(EXPORT_BUCKET).createSignedUrl(path, 900);
    if (signErr) return new Response(signErr.message, { status: 500 });

    return new Response(JSON.stringify({ url: signed.signedUrl, bucket: EXPORT_BUCKET, path }), { headers: { 'content-type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { 'content-type': 'application/json' } });
  }
});
