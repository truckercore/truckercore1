// deno-fns/legal_weekly.ts
// Weekly Legal Ops endpoint: returns CSV attachment and posts a short Slack/Teams summary line.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

function csv(rows: Array<Record<string, unknown>>) {
  const headers = Array.from(new Set(rows.flatMap(r => Object.keys(r))));
  const esc = (v: unknown) => {
    if (v == null) return "";
    const s = typeof v === "string" ? v : JSON.stringify(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g,'""')}"` : s;
  };
  return [headers.join(","), ...rows.map(r => headers.map(h => esc((r as any)[h])).join(","))].join("\n");
}

async function buildWeeklyLegalOpsStats() {
  // Minimal placeholder using legal_ops_weekly view if present
  try {
    const { data } = await db.from('legal_ops_weekly').select('*');
    const totals = (data || []).reduce((a: any, r: any) => ({
      new: (a.new || 0) + (r.new_reviews || 0),
      approved: (a.approved || 0) + (r.approvals || 0),
      rejected: (a.rejected || 0) + (r.rejections || 0),
      avg_hours: ((a._sum || 0) + (Number(r.avg_turnaround_hours) || 0)),
      _n: (a._n || 0) + 1,
      overdue: (a.overdue || 0) + (r.overdue_count || 0),
      top_blocker: (a.top_blocker || (r.top_blockers && r.top_blockers[0]?.blocker) || null),
    }), {});
    totals.avg_hours = totals._n ? totals.avg_hours / totals._n : 0;
    return totals;
  } catch {
    return { new: 0, approved: 0, rejected: 0, avg_hours: 0, overdue: 0, top_blocker: 'n/a' };
  }
}

async function buildWeeklyRows() {
  // Use legal_ops_weekly if available; otherwise return empty rows
  const { data, error } = await db.from('legal_ops_weekly').select('*');
  if (error) return [];
  return data as any[];
}

async function postSummaryToChat(text: string) {
  const SLACK_WEBHOOK = Deno.env.get('SLACK_WEBHOOK');
  const TEAMS_WEBHOOK = Deno.env.get('TEAMS_WEBHOOK');
  const msg = { text };
  try {
    if (SLACK_WEBHOOK) await fetch(SLACK_WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(msg) });
    if (TEAMS_WEBHOOK) await fetch(TEAMS_WEBHOOK, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(msg) });
  } catch { /* ignore */ }
}

Deno.serve( async (_req) => {
  const stats = await buildWeeklyLegalOpsStats();
  const rows = await buildWeeklyRows();
  const bodyCsv = csv(rows);
  const summary = `${stats.new || 0} new, ${stats.approved || 0} approved, ${stats.rejected || 0} rejected, avg ${(stats.avg_hours||0).toFixed(1)}h, ${stats.overdue || 0} overdue; top blocker: ${stats.top_blocker || 'n/a'}`;
  await postSummaryToChat(summary);
  const headers = new Headers({
    'Content-Type': 'text/csv',
    'Content-Disposition': `attachment; filename="legal-ops-${new Date().toISOString().slice(0,10)}.csv"`,
    'Cache-Control': 'no-store'
  });
  return new Response(bodyCsv, { status: 200, headers });
});