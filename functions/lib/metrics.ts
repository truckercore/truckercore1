import { auditInsert } from "./audit.ts";

/**
 * Lightweight metrics push helper.
 * Persists sampled counters/gauges via audit_log to avoid adding a new table.
 * If you later add a dedicated edge_metrics table, replace this implementation.
 */
export async function metricsPush(
  functionName: string,
  event: string,
  dims: Record<string, unknown> | null,
  request_id: string,
  sampleRate = 1.0,
) {
  try {
    await auditInsert(`metrics.${functionName}`, event, dims, request_id, sampleRate);
  } catch (e) {
    console.warn("metricsPush failed", e);
  }
}
