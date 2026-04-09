// ─── TruckerCore — alert-clustering-engine Edge Function ─────────────────────
// Deploy as: supabase/functions/alert-clustering-engine/index.ts
// Triggered by: cron every 5 minutes

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import type { AlertEvent } from '../_shared/types.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const CLUSTER_RULES = [
  {
    name: 'delivery_at_risk',
    label: 'Delivery at Risk',
    match: (alerts: AlertEvent[]) => {
      const types = new Set(alerts.map(a => a.alert_type));
      return (types.has('TRAFFIC_DELAY') || types.has('off_route'))
          && (types.has('late_eta')      || types.has('hos_eta_conflict'));
    },
    description: (alerts: AlertEvent[]) => {
      const types = [...new Set(alerts.map(a => a.alert_type))].join(', ');
      return `Delivery at risk due to: ${types.replace(/_/g, ' ').toLowerCase()}`;
    },
  },
  {
    name: 'compliance_risk',
    label: 'Compliance Risk',
    match: (alerts: AlertEvent[]) => {
      const types = new Set(alerts.map(a => a.alert_type));
      return (types.has('hos_eta_conflict') || types.has('hos_violation')) && types.has('inspection_due');
    },
    description: () => 'Driver approaching HOS limit near active inspection zone',
  },
  {
    name: 'hazard_corridor',
    label: 'Hazard Corridor',
    match: (alerts: AlertEvent[]) => alerts.filter(a => a.alert_type === 'weather_hazard').length >= 2,
    description: (alerts: AlertEvent[]) => {
      const count = alerts.filter(a => a.alert_type === 'weather_hazard').length;
      return `${count} hazards detected along current route`;
    },
  },
];

Deno.serve(async (_req) => {
  try {
    // 1. Get all organizations with open alerts
    const { data: orgs } = await supabase
      .from('alert_events')
      .select('org_id')
      .eq('status', 'open')
      .is('cluster_id', null)

    const uniqueOrgs = [...new Set(orgs?.map(o => o.org_id) || [])];
    let clustersCreated = 0;

    for (const orgId of uniqueOrgs) {
      // 2. Fetch recent open alerts for this org
      const { data: alerts } = await supabase
        .from('alert_events')
        .select('*')
        .eq('org_id', orgId)
        .eq('status', 'open')
        .is('cluster_id', null)
        .gte('created_at', new Date(Date.now() - 60 * 60 * 1000).toISOString())
        .order('created_at', { ascending: true })

      if (!alerts || alerts.length < 2) continue;

      // Group by driver/load
      const groups: Record<string, AlertEvent[]> = {};
      for (const alert of alerts) {
        const key = `${alert.driver_id || 'no-driver'}:${alert.load_id || 'no-load'}`;
        if (!groups[key]) groups[key] = [];
        groups[key].push(alert as AlertEvent);
      }

      for (const [key, group] of Object.entries(groups)) {
        if (group.length < 2) continue;
        const [driverId, loadId] = key.split(':');

        for (const rule of CLUSTER_RULES) {
          if (rule.match(group)) {
            const desc = rule.description(group);

            // Create cluster
            const { data: cluster, error: clusterError } = await supabase
              .from('alert_clusters')
              .insert({
                org_id: orgId,
                name: rule.name,
                label: rule.label,
                description: desc,
                driver_id: driverId === 'no-driver' ? null : driverId,
                load_id: loadId === 'no-load' ? null : loadId,
              })
              .select('id')
              .single()

            if (clusterError) {
              console.error('Cluster insert error:', clusterError);
              continue;
            }

            // Assign alerts to cluster
            await supabase
              .from('alert_events')
              .update({ cluster_id: cluster.id, updated_at: new Date().toISOString() })
              .in('id', group.map(a => a.id))

            clustersCreated++;
            break; // Move to next group once matched
          }
        }
      }
    }

    return new Response(JSON.stringify({ clustersCreated }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Clustering error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
