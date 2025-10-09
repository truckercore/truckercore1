// deno-fns/status_rss.ts
// Endpoint: /status/rss?component=api&format=atom|rss
// Generates RSS or Atom feed from recent public status incidents. Uses public.status_incidents table if present.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE")!;
const db = createClient(URL, KEY, { auth: { persistSession: false }});

function escapeXml(s: string) { return s.replace(/[<>&'\"]/g, c => ({'<':'&lt;','>':'&gt;','&':'&amp;',"'":'&apos','\"':'&quot;'} as any)[c] || c); }

async function fetchIncidents(component?: string) {
  // Prefer status_incidents table if available; fallback to stub
  try {
    let q = db.from("status_incidents").select("id,title,status,impact,components,started_at,resolved_at,updates").order("started_at", { ascending: false }).limit(50);
    const { data, error } = await q;
    if (error) throw error;
    let rows = (data || []) as any[];
    if (component) rows = rows.filter(r => Array.isArray(r.components) ? r.components.includes(component) : String(r.components || '').includes(component));
    return rows.map(r => ({
      id: String(r.id),
      title: String(r.title),
      link: `${Deno.env.get('STATUS_BASE_URL') || ''}/incidents/${r.id}`,
      summary: `${r.status} (${r.impact})`,
      ts: new Date(r.started_at || r.resolved_at || new Date()).getTime(),
      component: component || (Array.isArray(r.components) ? (r.components[0] || 'core') : 'core'),
      severity: r.impact || 'none',
    }));
  } catch {
    const all = [{ id: "1", title: "Status OK", link: String(Deno.env.get('STATUS_BASE_URL') || ''), summary: "All systems nominal", ts: Date.now(), component: "core", severity: "none" }];
    return component ? all.filter(i => i.component === component) : all;
  }
}

Deno.serve(async (req) => {
  const u = new URL(req.url);
  const component = u.searchParams.get("component") || undefined;
  const format = (u.searchParams.get("format") || "rss").toLowerCase();

  const incidents = await fetchIncidents(component);

  if (format === "atom") {
    const entries = incidents.map(i => `\n      <entry>\n        <id>tag:status:${escapeXml(i.id)}</id>\n        <title>${escapeXml(i.title)}</title>\n        <updated>${new Date(i.ts).toISOString()}</updated>\n        <link href="${escapeXml(i.link)}"/>\n        <category term="${escapeXml(i.component)}"/>\n        <summary>${escapeXml(i.summary)}</summary>\n      </entry>`).join("");
    const xml = `<?xml version="1.0" encoding="utf-8"?>\n<feed xmlns="http://www.w3.org/2005/Atom">\n  <title>TruckerCore Status</title>\n  <updated>${new Date().toISOString()}</updated>\n  ${entries}\n</feed>`;
    return new Response(xml, { headers: { "content-type": "application/atom+xml" } });
  }

  const items = incidents.map(i => `\n    <item>\n      <guid>${escapeXml(i.id)}</guid>\n      <title>${escapeXml(i.title)}</title>\n      <pubDate>${new Date(i.ts).toUTCString()}</pubDate>\n      <link>${escapeXml(i.link)}</link>\n      <category>${escapeXml(i.component)}</category>\n      <description>${escapeXml(i.summary)}</description>\n    </item>`).join("");
  const rss = `<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0"><channel>\n  <title>TruckerCore Status</title>\n  <lastBuildDate>${new Date().toUTCString()}</lastBuildDate>\n  ${items}\n</channel></rss>`;
  return new Response(rss, { headers: { "content-type": "application/rss+xml" } });
});