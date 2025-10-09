// deno deploy edge function
// Handle INSERT on safety_alerts and write coach_tips rows with short context tips.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts"

type Row = {
  id: string
  alert_type: 'SLOWDOWN'|'WORKZONE'|'WEATHER'|'SPEED'|'OFFROUTE'|'WEIGH'|'FATIGUE'
  fired_at: string
  message?: string | null
  org_id?: string | null
}

const TIPS: Record<Row['alert_type'], string> = {
  SLOWDOWN: 'Prepare early. Smooth braking reduces risk. Maintain ≥3 sec gap.',
  WORKZONE: 'Work zone ahead. Slow to posted advisory. Watch for flaggers.',
  WEATHER: 'Reduce speed in poor visibility. Double your following distance.',
  SPEED: 'Target ≤5 mph over limit; increase following distance.',
  OFFROUTE: 'Off planned route. Safest option: exit then re-route.',
  WEIGH: 'Approaching weigh/inspection. Ensure docs/ELD ready.',
  FATIGUE: 'Signs of fatigue. Plan a stop and rest before continuing.',
}

serve(async (req) => {
  const body = await req.json().catch(() => ({}))
  if (body.type !== 'INSERT') return new Response('ignored', { status: 200 })

  const rec = body.record as Row
  const tip = TIPS[rec.alert_type] ?? 'Drive defensively and maintain safe spacing.'
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2.57.2")
  const sb = createClient(supabaseUrl, supabaseServiceKey, { auth: { persistSession: false } })

  await sb.from('coach_tips').insert({
    alert_id: rec.id,
    org_id: rec.org_id ?? null,
    tip,
  })

  return new Response('ok', { status: 200 })
})
