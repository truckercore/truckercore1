// functions/_shared/opslog.ts
// Best-effort operations logger for Edge Functions. Writes to public.edge_request_log.
// Uses adminClient; ensure SUPABASE_SERVICE_ROLE_KEY is set in the Edge env.

import { adminClient } from './client.ts';

export async function opsLog(entry: {
  op: string;
  orgId?: string;
  traceId?: string;
  ok: boolean;
  ms: number;
  status: number;
  err?: string;
}) {
  try {
    const payload = [{
      op: entry.op,
      org_id: entry.orgId ?? null,
      trace_id: entry.traceId ?? null,
      ok: !!entry.ok,
      ms: Math.max(0, Math.round(entry.ms || 0)),
      status: entry.status,
      err: entry.err ? String(entry.err).slice(0, 500) : null,
    }];
    await adminClient.from('edge_request_log').insert(payload);
  } catch (_e) {
    // best-effort; never throw from logger
  }
}
