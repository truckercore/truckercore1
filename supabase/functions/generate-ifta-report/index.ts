/* eslint-disable no-console */
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { withRetries } from "../_shared/retry.ts";

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const org_id = url.searchParams.get("org_id");
    const quarter = url.searchParams.get("quarter"); // ISO date string representing any day in quarter
    if (!org_id || !quarter) {
      return new Response("Missing org_id or quarter", { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const rpcResult = await withRetries(async () => {
      const resp = await fetch(`${supabaseUrl}/rest/v1/rpc/ifta_quarter_csv`, {
        method: "POST",
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({ org: org_id, quarter_date: quarter }),
      });
      if (!resp.ok) {
        const txt = await resp.text();
        throw new Error(txt);
      }
      return resp.json() as Promise<{ state: string; miles: number; gallons: number }[]>;
    });

    const rows: { state: string; miles: number; gallons: number }[] = rpcResult;
    const header = "state,miles,gallons\n";
    const csv =
      header +
      rows.map((r) => `${r.state},${r.miles ?? 0},${r.gallons ?? 0}`).join("\n");

    return new Response(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv",
        "Content-Disposition": `attachment; filename="ifta_${org_id}_${quarter}.csv"`,
      },
    });
  } catch (e) {
    console.error(e);
    return new Response("Internal error", { status: 500 });
  }
});