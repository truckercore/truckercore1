import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")! // service role — bypasses RLS for writes
);

// ─── Types ────────────────────────────────────────────────────────────────────

interface GeofenceEvent {
  id: string;
  driver_id: string;
  user_id: string;           // fleet owner / account owner
  zone_id: string;
  zone_type: string;         // 'delivery', 'pickup', 'restricted', 'waypoint'
  event_type: "entry" | "exit";
  severity: "info" | "warning" | "critical";
  delay_minutes?: number;
  metadata?: Record<string, unknown>;
  created_at: string;
}

interface ProcessedAlert {
  alert_type: string;
  severity: "info" | "warning" | "critical";
  escalate: boolean;
  message: string;
}

// ─── UPGRADE 3: Alert Type Classification ─────────────────────────────────────

function classifyAlert(event: GeofenceEvent): ProcessedAlert {
  const { event_type, zone_type, delay_minutes = 0, severity } = event;

  // Missed delivery: exited delivery zone without completing
  if (event_type === "exit" && zone_type === "delivery") {
    return {
      alert_type: "missed_delivery",
      severity: "critical",
      escalate: true,
      message: `Driver exited delivery zone without confirming delivery.`,
    };
  }

  // Pickup zone exit without confirmation
  if (event_type === "exit" && zone_type === "pickup") {
    return {
      alert_type: "missed_pickup",
      severity: "warning",
      escalate: delay_minutes > 15,
      message: `Driver left pickup zone. Verify load was collected.`,
    };
  }

  // Late risk: still in zone past expected time
  if (delay_minutes > 30) {
    return {
      alert_type: "late_risk",
      severity: delay_minutes > 60 ? "critical" : "warning",
      escalate: delay_minutes > 60,
      message: `Driver is ${delay_minutes} minutes behind schedule.`,
    };
  }

  // Unauthorized zone entry (restricted areas)
  if (zone_type === "restricted" && event_type === "entry") {
    return {
      alert_type: "unauthorized_entry",
      severity: "critical",
      escalate: true,
      message: `Driver entered restricted zone. Immediate attention required.`,
    };
  }

  // Hazard proximity
  if (zone_type === "hazard") {
    return {
      alert_type: "hazard_proximity",
      severity: "critical",
      escalate: true,
      message: `Driver is near a hazard zone. Review route immediately.`,
    };
  }

  // Standard entry/exit
  return {
    alert_type: event_type === "entry" ? "geofence_entry" : "geofence_exit",
    severity: severity || "info",
    escalate: false,
    message: `Driver ${event_type === "entry" ? "entered" : "exited"} ${zone_type} zone.`,
  };
}

// ─── UPGRADE 6: Auto-Escalation ───────────────────────────────────────────────

async function escalate(event: GeofenceEvent, alert: ProcessedAlert) {
  console.log(`[ESCALATE] ${alert.alert_type} for driver ${event.driver_id}`);

  // ── Dispatcher dashboard real-time push via Supabase Realtime ──
  const channel = supabase.channel(`dispatcher:${event.user_id}`);
  await channel.send({
    type: "broadcast",
    event: "critical_alert",
    payload: {
      driver_id: event.driver_id,
      alert_type: alert.alert_type,
      message: alert.message,
      severity: alert.severity,
      geofence_event_id: event.id,
      timestamp: new Date().toISOString(),
    },
  });

  // ── Log escalation in billing events (Upgrade 7 bridge) ──
  await supabase.rpc("log_billing_event", {
    p_user_id: event.user_id,
    p_event_type: "alert_escalated",
    p_resource: "geofence_event",
    p_delta: 0,
    p_metadata: {
      alert_type: alert.alert_type,
      geofence_event_id: event.id,
      driver_id: event.driver_id,
    },
  });
}

// ─── UPGRADE 7: Billing ↔ Alert System Integration ────────────────────────────

async function checkAndEnforceBillingLimits(
  userId: string,
  actionType: string
) {
  // Example: enforce route creation limits
  if (actionType === "route_created") {
    const { data: allowed } = await supabase.rpc("increment_usage", {
      p_user_id: userId,
      p_field: "routes_today",
      p_limit_key: "max_routes_per_day",
    });

    if (!allowed) {
      // Log billing limit event
      await supabase.rpc("log_billing_event", {
        p_user_id: userId,
        p_event_type: "billing_limit_exceeded",
        p_resource: "route",
        p_delta: 0,
        p_metadata: { action: "route_created", blocked: true },
      });

      // Trigger upsell alert to the user's dashboard
      const channel = supabase.channel(`billing:${userId}`);
      await channel.send({
        type: "broadcast",
        event: "limit_exceeded",
        payload: {
          resource: "routes_today",
          message:
            "You've reached your daily route limit. Upgrade to Fleet Pro for unlimited routes.",
          cta_url: "/upgrade",
        },
      });

      return false;
    }
  }

  return true;
}

// ─── UPGRADE 5: Priority Queue Insert ─────────────────────────────────────────
// The v_alert_priority_queue VIEW handles SELECT ordering.
// This function writes the enriched event back so the view stays fresh.

async function persistEnrichedEvent(
  event: GeofenceEvent,
  alert: ProcessedAlert
) {
  const { error } = await supabase
    .from("geofence_events")
    .update({
      alert_type: alert.alert_type,
      severity: alert.severity,
    })
    .eq("id", event.id);

  if (error) {
    console.error("[PERSIST] Failed to update geofence event:", error.message);
    throw error;
  }
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let event: GeofenceEvent;
  try {
    event = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    // 1. Classify the alert (Upgrade 3)
    const alert = classifyAlert(event);
    console.log(`[CLASSIFY] ${event.id} → ${alert.alert_type} (${alert.severity})`);

    // 2. Persist enriched event so priority queue view is accurate (Upgrade 5)
    await persistEnrichedEvent(event, alert);

    // 3. Escalate if needed (Upgrade 6)
    if (alert.escalate || alert.severity === "critical") {
      await escalate(event, alert);
    }

    // 4. Billing integration — check if event triggers a usage event (Upgrade 7)
    if (event.metadata?.action_type) {
      await checkAndEnforceBillingLimits(
        event.user_id,
        event.metadata.action_type as string
      );
    }

    return new Response(
      JSON.stringify({ success: true, alert_type: alert.alert_type, severity: alert.severity }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("[ERROR]", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
