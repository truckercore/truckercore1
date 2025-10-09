import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
if (!ANON) {
  throw new Error("Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)");
}
if (!Deno.env.get("SUPABASE_ANON") && Deno.env.get("SUPABASE_ANON_KEY")) {
  console.warn("[deprecation] SUPABASE_ANON_KEY is deprecated in Edge Functions; please set SUPABASE_ANON instead");
}
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(URL, ANON, { global: { headers: { Authorization: authHeader } } });
  const admin = createClient(URL, SERVICE);

  const { data: ures } = await userClient.auth.getUser();
  const user = ures?.user;
  if (!user) return new Response("Unauthorized", { status: 401 });

  const { data: prof } = await userClient.from("profiles").select("org_id").eq("user_id", user.id).single();
  const org_id = (prof as any)?.org_id;
  if (!org_id) return new Response("No org", { status: 400 });

  const params = req.method === "POST" ? await req.json().catch(() => ({})) : {};
  let { tms_run_id, acct_run_id } = params as { tms_run_id?: number; acct_run_id?: number };

  if (!tms_run_id || !acct_run_id) {
    const { data: latest } = await admin.from("connectors.v_last_runs")
      .select("*").eq("org_id", org_id).single();
    if (!latest) return new Response("No successful runs yet", { status: 400 });
    tms_run_id = tms_run_id ?? (latest as any).last_tms_run_id;
    acct_run_id = acct_run_id ?? (latest as any).last_acct_run_id;
  }

  const { data: tmsRows } = await admin
    .from("connectors.tms_staging_loads")
    .select("ref_number,billable_amount_cents")
    .eq("org_id", org_id).eq("run_id", tms_run_id);

  const { data: acctRows } = await admin
    .from("connectors.acct_staging_invoices")
    .select("ref_number,amount_cents,status")
    .eq("org_id", org_id).eq("run_id", acct_run_id);

  const tmsMap = new Map<string, number>();
  (tmsRows ?? []).forEach((r: any) => tmsMap.set(r.ref_number, r.billable_amount_cents ?? 0));

  const acctMap = new Map<string, { amt: number; status: string | null }>();
  (acctRows ?? []).forEach((r: any) => acctMap.set(r.ref_number, { amt: r.amount_cents ?? 0, status: r.status ?? null }));

  // Total is union of references across both sources
  const allRefs = new Set<string>([...tmsMap.keys(), ...acctMap.keys()]);
  const total = allRefs.size;

  let matched = 0, mismatchedAmt = 0, missingInv = 0, missingLoad = 0;

  // Clear previous lines for this run pair
  await admin.from("connectors.recon_lines")
    .delete()
    .eq("org_id", org_id).eq("tms_run_id", tms_run_id).eq("acct_run_id", acct_run_id);

  for (const ref of allRefs) {
    const tmsAmt = tmsMap.get(ref);
    const acct = acctMap.get(ref);

    if (tmsAmt == null && acct != null) {
      missingLoad++;
      await admin.from("connectors.recon_lines").insert({
        org_id, tms_run_id, acct_run_id, ref_number: ref, issue: 'missing_load',
        acct_amount_cents: acct.amt, acct_status: acct.status, details: {}
      });
      continue;
    }
    if (tmsAmt != null && acct == null) {
      missingInv++;
      await admin.from("connectors.recon_lines").insert({
        org_id, tms_run_id, acct_run_id, ref_number: ref, issue: 'missing_invoice',
        tms_amount_cents: tmsAmt, details: {}
      });
      continue;
    }
    // both exist
    if (Math.abs((acct!.amt ?? 0) - (tmsAmt ?? 0)) === 0) {
      matched++;
    } else {
      mismatchedAmt++;
      await admin.from("connectors.recon_lines").insert({
        org_id, tms_run_id, acct_run_id, ref_number: ref, issue: 'amount_mismatch',
        tms_amount_cents: tmsAmt, acct_amount_cents: acct!.amt, acct_status: acct!.status, details: {}
      });
    }
  }

  const summary = {
    tms_run_id, acct_run_id, total, matched, mismatched_amounts: mismatchedAmt,
    missing_invoices: missingInv, missing_loads: missingLoad
  };

  const { data: rec } = await admin.from("connectors.recon_results").insert({
    org_id, tms_run_id, acct_run_id,
    total_loads: total, matched, mismatched_amounts: mismatchedAmt,
    missing_invoices: missingInv, missing_loads: missingLoad, summary
  }).select("id").single();

  const green = matched === total && missingInv === 0 && missingLoad === 0 && mismatchedAmt === 0;

  return new Response(JSON.stringify({ result_id: (rec as any)?.id, green_check: green, summary }), {
    status: 200,
    headers: { "content-type": "application/json" }
  });
});
