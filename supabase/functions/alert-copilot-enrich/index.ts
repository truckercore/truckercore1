import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import type {
  AlertEvent, AlertType, AlertSeverity, UserRole,
  CopilotInputPayload, CopilotOutputPayload,
} from '../_shared/types.ts'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const AI_MODEL        = 'claude-sonnet-4-20250514'
const PROMPT_VERSION  = 'v1.2.0'
const MAX_TOKENS      = 512
const CONFIDENCE_CLAMP = (v: number) => Math.min(1, Math.max(0, v))

// ─── System Prompt ────────────────────────────────────────────────────────────

const SYSTEM_PROMPT = `
You are an operations alert copilot for a commercial trucking and freight logistics platform called TruckerCore.

Your role:
- Analyze structured alert data and produce plain-English explanations
- Assess urgency and confidence
- Recommend concrete, actionable next steps
- Assign the right role to act
- Flag whether auto-escalation is warranted

Rules you MUST follow:
- Use ONLY the data provided. Do not invent facts, locations, or times.
- Return ONLY valid JSON. No prose outside the JSON object.
- Keep explanations factual and direct — written for a dispatcher or fleet manager.
- Recommended actions must be specific and operational (no generic advice).
- Confidence must be between 0.0 and 1.0.
- severity must be one of: low, medium, high, critical.
- assignee_role must be one of: driver, dispatcher, fleet_admin, broker, owner_operator.
- auto_escalate should be true only for high/critical alerts that require human action within 15 minutes.

JSON output schema (strict):
{
  "severity": "critical" | "high" | "medium" | "low",
  "confidence": number,
  "title": string,
  "summary": string,
  "explanation": string,
  "recommended_action": string,
  "assignee_role": string,
  "auto_escalate": boolean,
  "secondary_assignees": string[],
  "estimated_resolution_minutes": number,
  "financial_impact_note": string | null
}
`.trim()

// ─── Context Builder ──────────────────────────────────────────────────────────

async function buildCopilotPayload(alert: AlertEvent): Promise<CopilotInputPayload> {
  const meta = alert.metadata

  // Enrich with live driver context
  let driverName: string | null = null
  let vehicleUnit: string | null = null
  let loadReference: string | null = null

  if (alert.driver_id) {
    const { data: p } = await supabase
      .from('profiles').select('full_name').eq('id', alert.driver_id).maybeSingle()
    driverName = p?.full_name ?? null
  }

  if (alert.vehicle_id) {
    const { data: v } = await supabase
      .from('vehicles').select('unit_number').eq('id', alert.vehicle_id).maybeSingle()
    vehicleUnit = v?.unit_number ?? null
  }

  if (alert.load_id) {
    const { data: l } = await supabase
      .from('loads').select('reference').eq('id', alert.load_id).maybeSingle()
    loadReference = l?.reference ?? null
  }

  // Fetch last 3 open alerts for this driver (context window)
  const recentEvents: string[] = []
  if (alert.driver_id) {
    const { data: recent } = await supabase
      .from('alert_events')
      .select('alert_type, severity, created_at')
      .eq('driver_id', alert.driver_id)
      .eq('org_id', alert.org_id)
      .neq('id', alert.id)
      .in('status', ['open', 'acknowledged'])
      .order('created_at', { ascending: false })
      .limit(3)

    recent?.forEach(r => {
      recentEvents.push(`${r.alert_type} (${r.severity}) at ${new Date(r.created_at).toLocaleTimeString()}`)
    })
  }

  return {
    alert_type:               alert.alert_type as AlertType,
    driver_name:              driverName,
    vehicle_unit:             vehicleUnit ?? (meta.vehicle_unit as string ?? null),
    load_reference:           loadReference ?? (meta.load_reference as string ?? null),
    current_location:         meta.current_location as string ?? null,
    planned_eta:              meta.planned_eta as string ?? null,
    predicted_eta:            meta.predicted_eta as string ?? null,
    delivery_window_end:      meta.delivery_window_end as string ?? null,
    hos_remaining_minutes:    (meta.hos_remaining_minutes as number) ?? null,
    traffic_delay_minutes:    (meta.traffic_delay_minutes as number) ?? null,
    weather_risk:             meta.weather_risk as string ?? null,
    route_deviation_miles:    (meta.route_deviation_miles as number) ?? null,
    deviation_duration_minutes:(meta.deviation_minutes as number) ?? null,
    speed_mph:                (meta.speed_mph as number) ?? null,
    speed_limit_mph:          (meta.speed_limit_mph as number) ?? null,
    idle_duration_minutes:    (meta.idle_duration_minutes as number) ?? null,
    maintenance_type:         meta.maintenance_type as string ?? null,
    miles_until_service:      (meta.miles_until_service as number) ?? null,
    inspection_expiry_date:   meta.inspection_expiry_date as string ?? null,
    days_until_expiry:        (meta.days_until_expiry as number) ?? null,
    geofence_name:            meta.geofence_name as string ?? null,
    dispatcher_notes:         null,
    recent_events:            recentEvents,
  }
}

// ─── AI Call ──────────────────────────────────────────────────────────────────

async function callCopilot(payload: CopilotInputPayload): Promise<CopilotOutputPayload> {
  const userMessage = JSON.stringify(payload, null, 0)

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY')!,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: AI_MODEL,
      max_tokens: MAX_TOKENS,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: userMessage }],
    }),
  })

  if (!response.ok) {
    throw new Error(`Anthropic API error: ${response.status} ${await response.text()}`)
  }

  const data = await response.json()
  const raw = data.content?.[0]?.text ?? ''

  // Strip markdown fences if present
  const cleaned = raw.replace(/^```json\s*/i, '').replace(/\s*```$/, '').trim()
  const parsed: CopilotOutputPayload = JSON.parse(cleaned)

  return parsed
}

// ─── Fallback Template ────────────────────────────────────────────────────────
// Used when AI fails — deterministic fallback based on alert type

function fallbackEnrichment(alert: AlertEvent): CopilotOutputPayload {
  const fallbacks: Partial<Record<string, Omit<CopilotOutputPayload, 'title' | 'summary'>>> = {
    driver_sos: {
      severity: 'critical', confidence: 1.0,
      explanation: 'Driver SOS flag activated. Requires immediate dispatcher response.',
      recommended_action: 'Call driver immediately. If no answer, dispatch emergency services.',
      assignee_role: 'dispatcher', auto_escalate: true,
      secondary_assignees: ['fleet_admin'], estimated_resolution_minutes: 5, financial_impact_note: null,
    },
    hos_eta_conflict: {
      severity: 'critical', confidence: 0.95,
      explanation: 'Driver cannot legally complete this load without a mandatory rest break.',
      recommended_action: 'Pause load immediately. Schedule 10-hour reset or reassign to compliant driver.',
      assignee_role: 'dispatcher', auto_escalate: true,
      secondary_assignees: ['fleet_admin'], estimated_resolution_minutes: 30, financial_impact_note: 'Potential late penalty if not rerouted.',
    },
    off_route: {
      severity: alert.severity, confidence: 0.85,
      explanation: 'Vehicle has deviated from planned route beyond threshold.',
      recommended_action: 'Contact driver to verify route issue or unplanned stop.',
      assignee_role: 'dispatcher', auto_escalate: false,
      secondary_assignees: [], estimated_resolution_minutes: 15, financial_impact_note: null,
    },
  }

  const base = fallbacks[alert.alert_type] ?? {
    severity: alert.severity, confidence: 0.70,
    explanation: 'Alert generated by rules engine. Manual review required.',
    recommended_action: 'Review alert details and take appropriate action.',
    assignee_role: 'dispatcher' as UserRole, auto_escalate: false,
    secondary_assignees: [], estimated_resolution_minutes: 20, financial_impact_note: null,
  }

  return { title: alert.title, summary: alert.summary, ...base }
}

// ─── Output Validation ────────────────────────────────────────────────────────

const VALID_SEVERITIES: AlertSeverity[] = ['low', 'medium', 'high', 'critical']
const VALID_ROLES: UserRole[] = ['driver', 'dispatcher', 'fleet_admin', 'broker', 'owner_operator']

function validateOutput(raw: CopilotOutputPayload, alert: AlertEvent): CopilotOutputPayload {
  if (!VALID_SEVERITIES.includes(raw.severity)) raw.severity = alert.severity
  if (!VALID_ROLES.includes(raw.assignee_role)) raw.assignee_role = 'dispatcher'
  if (typeof raw.confidence !== 'number') raw.confidence = 0.75
  raw.confidence = CONFIDENCE_CLAMP(raw.confidence)
  if (!raw.title?.trim()) raw.title = alert.title
  if (!raw.summary?.trim()) raw.summary = alert.summary
  if (!raw.explanation?.trim()) raw.explanation = 'No explanation available.'
  if (!raw.recommended_action?.trim()) raw.recommended_action = 'Review alert and take appropriate action.'
  if (typeof raw.auto_escalate !== 'boolean') raw.auto_escalate = false

  // Safety guardrail: never auto-resolve critical alerts via AI alone
  if (raw.severity === 'critical') raw.auto_escalate = true

  return raw
}

// ─── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  try {
    const { alert_id } = await req.json() as { alert_id: string }
    if (!alert_id) return new Response(JSON.stringify({ error: 'alert_id required' }), { status: 400 })

    // Fetch alert
    const { data: alert, error: fetchError } = await supabase
      .from('alert_events')
      .select('*')
      .eq('id', alert_id)
      .single()

    if (fetchError || !alert) {
      return new Response(JSON.stringify({ error: 'Alert not found' }), { status: 404 })
    }

    // Skip if already AI-enriched
    if (alert.ai_generated) {
      return new Response(JSON.stringify({ skipped: true, reason: 'already_enriched' }))
    }

    // Build input payload
    const payload = await buildCopilotPayload(alert as AlertEvent)

    // Call AI with fallback
    let output: CopilotOutputPayload
    try {
      output = await callCopilot(payload)
    } catch (aiErr) {
      console.warn('AI call failed, using fallback:', aiErr)
      output = fallbackEnrichment(alert as AlertEvent)
    }

    // Validate output
    output = validateOutput(output, alert as AlertEvent)

    // Update alert with enrichment
    const { error: updateError } = await supabase
      .from('alert_events')
      .update({
        severity:           output.severity,
        title:              output.title,
        summary:            output.summary,
        explanation:        output.explanation,
        recommended_action: output.recommended_action,
        confidence:         output.confidence,
        assignee_role:      output.assignee_role,
        auto_escalate:      output.auto_escalate,
        ai_generated:       true,
        updated_at:         new Date().toISOString(),
        metadata: {
          ...alert.metadata,
          ai_model_version:               AI_MODEL,
          prompt_version:                 PROMPT_VERSION,
          secondary_assignees:            output.secondary_assignees ?? [],
          estimated_resolution_minutes:   output.estimated_resolution_minutes,
          financial_impact_note:          output.financial_impact_note,
        },
      })
      .eq('id', alert_id)

    if (updateError) throw updateError

    // Audit log
    await supabase.from('alert_action_log').insert({
      alert_id,
      action_type: 'ai_enriched',
      metadata: {
        model:          AI_MODEL,
        prompt_version: PROMPT_VERSION,
        confidence:     output.confidence,
        severity:       output.severity,
      },
    })

    // Queue in-app notifications to appropriate roles
    await queueNotifications(alert_id, alert.org_id, output.assignee_role, output.auto_escalate)

    return new Response(JSON.stringify({ enriched: true, severity: output.severity }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Copilot enrichment error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})

// ─── Notification Queueing ────────────────────────────────────────────────────

async function queueNotifications(
  alertId: string,
  orgId: string,
  assigneeRole: UserRole,
  autoEscalate: boolean
): Promise<void> {
  // Get users in org matching role
  const roles = autoEscalate
    ? [assigneeRole, 'fleet_admin']
    : [assigneeRole]

  const { data: recipients } = await supabase
    .from('profiles')
    .select('id')
    .eq('org_id', orgId)
    .in('role', roles)

  if (!recipients?.length) return

  const rows = recipients.map(r => ({
    alert_id:          alertId,
    recipient_user_id: r.id,
    channel:           'in_app' as const,
    delivery_status:   'pending',
    scheduled_for:     new Date().toISOString(),
  }))

  await supabase.from('alert_notification_queue').insert(rows)
}
