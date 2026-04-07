// TypeScript
// supabase/functions/kpi-aggregate-export/index.ts
// Deploy: supabase functions deploy kpi-aggregate-export --no-verify-jwt=false
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function toCSV(rows: any[]): string {
  if (!rows.length) return "";
  const cols = Object.keys(rows[0]);
  const esc = (v: any) => (v == null ? "" : String(v).includes(",") || String(v).includes('"') ? `"${String(v).replace(/"/g, '""')}"` : String(v));
  const header = cols.join(",");
  const body = rows.map((r) => cols.map((c) => esc(r[c])).join(",")).join("\n");
  return `${header}\n${body}`;
}

export const handler = async (req: Request) => {
  try {
    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "aggregate"; // aggregate | export_csv | export_pdf
    const day = url.searchParams.get("day") ?? new Date().toISOString().slice(0, 10);
    const org = url.searchParams.get("org_id");

    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

    if (action === "aggregate") {
      const { error } = await sb.rpc("refresh_kpi_daily", { p_day: day, p_org: org || null });
      if (error) return new Response(`agg failed: ${error.message}`, { status: 500 });
      return new Response("ok");
    }

    if (action === "export_csv") {
      const qs = new URLSearchParams();
      qs.set("day", `eq.${day}`);
      if (org) qs.set("org_id", `eq.${org}`);
      const r = await fetch(`${Deno.env.get("SUPABASE_URL")}/rest/v1/v_kpi_insurer_export?${qs}`, {
        headers: {
          apikey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
          Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!}`,
          Accept: "application/json",
        },
      });
      if (!r.ok) return new Response(await r.text(), { status: r.status });
      const rows = await r.json();
      const csv = toCSV(rows);
      return new Response(csv, {
        headers: {
          "Content-Type": "text/csv; charset=utf-8",
          "Content-Disposition": `attachment; filename="kpi_${day}.csv"`,
        },
      });
    }

    if (action === "export_pdf") {
      // Minimal placeholder PDF: serve plain text with pdf content-type
      const text = `KPI Report\nDate: ${day}\nOrg: ${org ?? "ALL"}\nSee CSV for detailed metrics.`;
      return new Response(text, {
        headers: {
          "Content-Type": "application/pdf",
          "Content-Disposition": `attachment; filename="kpi_${day}.pdf"`,
        },
      });
    }

    return new Response("unknown action", { status: 400 });
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }
};

Deno.serve(handler);
