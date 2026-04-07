import { supabaseAdmin } from "./db.ts";

export async function auditInsert(table_name: string, action: string, new_values: Record<string, unknown> | null, request_id: string, sampleRate = 1.0) {
  try {
    if (Math.random() > sampleRate) return;
    await supabaseAdmin.from("audit_log").insert({
      table_name,
      record_id: null,
      action,
      edited_by: null,
      old_values: null,
      new_values: { ...new_values, request_id },
    });
  } catch (e) {
    console.warn("audit insert failed", e);
  }
}
