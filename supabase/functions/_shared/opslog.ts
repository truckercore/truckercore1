import { getServiceClient } from "../_shared/client.ts";

// Best-effort operations logger for Edge functions. Never throws.
export async function opsLog(entry: {
  op: string; orgId?: string; traceId?: string; ok: boolean; ms: number; status: number; err?: string;
}) {
  try {
    const db = getServiceClient();
    await db.from('edge_request_log').insert([{
      op: entry.op,
      org_id: entry.orgId ?? null,
      trace_id: entry.traceId ?? null,
      ok: entry.ok,
      ms: Math.max(0, Math.round(entry.ms)),
      status: entry.status,
      err: entry.err ? String(entry.err).slice(0, 500) : null,
    }]);
  } catch (_e) {
    // swallow
  }
}
