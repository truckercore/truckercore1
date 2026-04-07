import { serve } from "std/server";
import { getMaintenanceEvents, notifyOwnerOperator, supabaseAdmin } from "../lib/db.ts";
import { makeRequestId, ok, badRequest, error as errResp } from "../lib/http.ts";

// Preventive Maintenance Reminder
// Deploy: supabase functions deploy maintenance-reminder --no-verify-jwt
// Invoke: supabase functions invoke maintenance-reminder -b '{"owner_op_id":"uuid"}'

serve(async (req) => {
  const started = Date.now();
  const request_id = makeRequestId(req);
  try {
    const { owner_op_id } = await req.json();
    if (!owner_op_id) {
      return badRequest("owner_op_id required", request_id);
    }

    const reminders = await getMaintenanceEvents(owner_op_id);

    const in7days = Date.now() + 7 * 24 * 60 * 60 * 1000;
    const dueSoon = reminders.filter((evt: any) => {
      const scheduledSoon = evt.scheduled_time && new Date(evt.scheduled_time).getTime() < in7days;
      const odoLogic = typeof evt.last_odometer === "number" && typeof evt.odometer === "number"
        ? (evt.odometer - evt.last_odometer) < 500
        : false;
      return !evt.completed && (scheduledSoon || odoLogic);
    });

    if (dueSoon.length > 0) {
      await notifyOwnerOperator(owner_op_id, "Maintenance Due Soon!", JSON.stringify(dueSoon));
    }

    const latency_ms = Date.now() - started;
    try {
      await supabaseAdmin.from("audit_log").insert({
        table_name: "edge.maintenance_reminder",
        record_id: null,
        action: "notify",
        edited_by: null,
        old_values: null,
        new_values: { owner_op_id, reminders_total: Array.isArray(reminders) ? reminders.length : 0, due_soon: dueSoon.length, notified: dueSoon.length > 0, latency_ms, request_id },
      });
    } catch (e) {
      console.warn("audit insert failed", e);
    }

    return ok({ dueSoon, latency_ms }, request_id);
  } catch (err) {
    console.error("maintenance_reminder error", request_id, err);
    return errResp(String(err), request_id, 500);
  }
});
