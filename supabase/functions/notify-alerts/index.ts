// deno
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const slackUrl = Deno.env.get("SLACK_WEBHOOK_URL"); // optional

  const supabase = createClient(url, serviceKey);

  const { data: rows, error } = await supabase
    .from("alert_outbox")
    .select("*")
    .is("delivered_at", null)
    .order("created_at", { ascending: true })
    .limit(50);

  if (error) {
    return new Response(error.message, { status: 500 });
  }

  let delivered = 0;

  for (const r of rows ?? []) {
    // Optional Grafana SLI link for canary/burn-rate incidents
    const grafBase = Deno.env.get('GRAFANA_SLI_BASE');
    const fn = (r as any).payload?.fn as string | undefined;
    const graf = grafBase && fn ? `\n\nSLI: ${grafBase}?var-fn=${encodeURIComponent(fn)}` : '';
    const text = `🚨 ${(r as any).key}\n\`\`\`${JSON.stringify((r as any).payload, null, 2)}\`\`\`${graf}`;

    // Fetch routing channel for this alert key (default to 'slack')
    let channel = 'slack';
    try {
      const { data: route, error: routeErr } = await supabase
        .from('alert_routes')
        .select('channel')
        .eq('key', (r as any).key)
        .maybeSingle();
      if (!routeErr && route?.channel) channel = String(route.channel).toLowerCase();
    } catch (_) {
      // ignore, keep default channel
    }

    // Delivery branches based on channel
    switch (channel) {
      case 'email': {
        const notifyTo = (r as any).payload?.notify_to as string[] | undefined;
        if (notifyTo && notifyTo.length > 0 && Deno.env.get('RESEND_API_KEY')) {
          try {
            await fetch('https://api.resend.com/emails', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
              },
              body: JSON.stringify({
                from: Deno.env.get('ALERTS_FROM_EMAIL') ?? 'alerts@example.com',
                to: notifyTo,
                subject: `Alert: ${(r as any).key}`,
                html: `<pre style="white-space:pre-wrap">${text.replaceAll('\n', '<br/>')}</pre>`,
              }),
            });
          } catch {
            // leave undelivered; will retry later
            continue;
          }
        } else {
          // No recipients configured; skip delivery so it can be picked up after config.
          continue;
        }
        break;
      }
      case 'pager': {
        const key = Deno.env.get('PAGERDUTY_ROUTING_KEY');
        // Quiet hours logic: only page during 22:00–06:00 if Sev1/escalated or marked critical
        const quietStart = Number(Deno.env.get('QUIET_HOURS_START') ?? '22');
        const quietEnd = Number(Deno.env.get('QUIET_HOURS_END') ?? '6');
        const hour = new Date().getUTCHours(); // assume UTC; set local via infra if desired
        const spansMidnight = quietStart > quietEnd;
        const inQuiet = spansMidnight ? (hour >= quietStart || hour < quietEnd) : (hour >= quietStart && hour < quietEnd);
        const severity = ((r as any).payload?.severity as string | undefined)?.toLowerCase() || '';
        const isEscalated = String((r as any).key || '').endsWith('_escalated');
        const burnRate = Number((r as any).payload?.burn_rate ?? 0);
        const allowDuringQuiet = isEscalated || severity === 'critical' || burnRate >= Number(Deno.env.get('QUIET_HOURS_MIN_BURN') ?? '2');
        if (inQuiet && !allowDuringQuiet) {
          // Skip paging during quiet hours for non-critical alerts; leave undelivered to retry later
          continue;
        }
        if (key) {
          try {
            await fetch('https://events.pagerduty.com/v2/enqueue', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                routing_key: key,
                event_action: 'trigger',
                payload: {
                  summary: `${(r as any).key} – ${JSON.stringify((r as any).payload)}`.slice(0, 1024),
                  source: 'truckercore',
                  severity: 'error',
                  component: ((r as any).payload?.fn ?? 'core'),
                  group: (r as any).key,
                  class: 'slo/alert'
                },
                dedup_key: (r as any).dedupe_key?.slice(0, 255)
              })
            });
          } catch {
            continue; // will retry next loop
          }
        } else {
          continue; // no PD key configured
        }
        break;
      }
      case 'slack':
      default: {
        if (slackUrl) {
          try {
            const res = await fetch(slackUrl, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ text }),
            });
            if (!res.ok) {
              // Leave undelivered; will retry on next run
              continue;
            }
          } catch {
            // Network error; leave undelivered
            continue;
          }
        } else {
          // No Slack configured; leave undelivered for later
          continue;
        }
        break;
      }
    }

    const up = await supabase
      .from('alert_outbox')
      .update({ delivered_at: new Date().toISOString() })
      .eq('id', (r as any).id);

    if (!up.error) delivered += 1;
  }

  return new Response(JSON.stringify({ delivered }), {
    headers: { "Content-Type": "application/json" },
  });
});
