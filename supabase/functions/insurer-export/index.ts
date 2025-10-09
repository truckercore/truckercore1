// TypeScript
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encode as csvEncode } from "https://deno.land/std@0.224.0/csv/mod.ts";
import { PDFDocument, StandardFonts } from "https://esm.sh/pdf-lib@1.17.1";

export const handler = async (req: Request) => {
  const url = new URL(req.url);
  const org_id = url.searchParams.get("org_id") ?? "";
  const month = url.searchParams.get("month") ?? ""; // "YYYY-MM"

  if (!org_id || !month) return new Response("Missing org_id or month", { status: 400 });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) return new Response("Missing SUPABASE env", { status: 500 });

  const supabase = createClient(supabaseUrl, serviceKey);

  const { data: kpis, error } = await supabase
    .from("kpi_daily")
    .select("*")
    .gte("day", `${month}-01`)
    .lte("day", `${month}-31`)
    .eq("org_id", org_id);
  if (error) return new Response(error.message, { status: 400 });

  const csv = await csvEncode((kpis ?? []) as any[]);

  const pdf = await PDFDocument.create();
  const page = pdf.addPage([612, 792]);
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const draw = (text: string, y: number) => page.drawText(text, { x: 48, y, size: 12, font });

  draw(`TruckerCore Safety Report — Org ${org_id}` as string, 740);
  draw(`Period: ${month}` as string, 720);

  const totals = (kpis ?? []).reduce(
    (a: any, r: any) => {
      a.alerts += r.alerts ?? 0;
      a.acks += r.acks ?? 0;
      a.near += r.near_misses ?? 0;
      return a;
    },
    { alerts: 0, acks: 0, near: 0 }
  );

  draw(
    `Alerts: ${totals.alerts}   Acks: ${totals.acks}   Ack Rate: ` +
      (totals.alerts ? `${((totals.acks / totals.alerts) * 100).toFixed(1)}%` : `—`),
    690,
  );
  draw(`Near Misses: ${totals.near}`, 670);
  draw(`Notes: Daily KPIs attached as CSV.`, 650);

  const pdfBytes = await pdf.save();

  const boundary = "MIXED-" + crypto.randomUUID();
  const body =
    `--${boundary}\r\nContent-Type: text/csv; name="insurer_kpis_${month}.csv"\r\n\r\n${csv}\r\n` +
    `--${boundary}\r\nContent-Type: application/pdf; name="insurer_summary_${month}.pdf"\r\nContent-Transfer-Encoding: base64\r\n\r\n${btoa(String.fromCharCode(...pdfBytes))}\r\n` +
    `--${boundary}--`;

  return new Response(body, {
    headers: { "Content-Type": `multipart/mixed; boundary=${boundary}` },
  });
};

Deno.serve(handler);
