// apps/web/src/lib/integrations/providers/samsara.ts
import { ensureIdempotent } from "../sdk";

export async function samsaraIngestPositions(params: {
  orgId: string;
  token: string;
  afterIso?: string;
}) {
  const base = "https://api.samsara.com/fleet/vehicles/locations";
  const url = new URL(base);
  if (params.afterIso) url.searchParams.set("startTime", params.afterIso);

  const r = await fetch(url.toString(), { headers: { Authorization: `Bearer ${params.token}` } });
  if (!r.ok) throw new Error(`samsara positions: ${r.status} ${await r.text()}`);
  const data = await r.json();

  const rows = (data?.data ?? []).flatMap((v: any) => {
    return (v?.locations ?? []).map((p: any) => ({
      org_id: params.orgId,
      vehicle_id: null,
      driver_id: null,
      provider: "samsara",
      provider_msg_id: `${v.id}:${p.time}`,
      ts: new Date(p.time).toISOString(),
      geom: `SRID=4326;POINT(${p.longitude} ${p.latitude})`,
      speed_kph: p.speed ?? null,
      heading: p.heading ?? null,
      ignition: p.ignitionOn ?? null,
    }));
  });

  if (!rows.length) return { inserted: 0 };

  const ok = await ensureIdempotent(`samsara-${params.orgId}-${rows[0].provider_msg_id}`, "samsara", params.orgId);
  if (!ok) return { status: "skipped" } as any;

  const insert = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/positions`, {
    method: "POST",
    headers: {
      apikey: process.env.SUPABASE_SERVICE_ROLE_KEY as string,
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify(rows),
  });
  if (!insert.ok) throw new Error(`insert positions failed: ${insert.status} ${await insert.text()}`);
  return { inserted: rows.length };
}
