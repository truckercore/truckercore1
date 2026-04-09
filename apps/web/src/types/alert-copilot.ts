// ─── TruckerCore AI Alert Copilot — Type Definitions ─────────────────────────
// Version: 1.0.0 | Stack: Next.js / TypeScript / Supabase

export type AlertSeverity = 'low' | 'medium' | 'high' | 'critical';
export type AlertStatus  = 'open' | 'acknowledged' | 'resolved' | 'dismissed' | 'snoozed';
export type AlertSource  = 'system' | 'ai' | 'manual' | 'driver' | 'telematics';
export type UserRole     = 'driver' | 'dispatcher' | 'fleet_admin' | 'broker' | 'owner_operator';
export type DeliveryChannel = 'in_app' | 'push' | 'sms' | 'email' | 'webhook';

export type AlertType =
  | 'off_route'
  | 'late_eta'
  | 'hos_violation'
  | 'hos_eta_conflict'
  | 'geofence_enter'
  | 'geofence_exit'
  | 'idle_too_long'
  | 'speeding'
  | 'harsh_braking'
  | 'harsh_acceleration'
  | 'missed_pickup'
  | 'missed_delivery'
  | 'inspection_due'
  | 'maintenance_threshold'
  | 'load_exception'
  | 'weather_hazard'
  | 'driver_sos'
  | 'detention_risk'
  | 'compliance_expiry'
  | 'fuel_anomaly';

// ─── Database Row Types ───────────────────────────────────────────────────────

export interface AlertEvent {
  id: string;
  org_id: string;
  driver_id: string | null;
  vehicle_id: string | null;
  load_id: string | null;
  alert_type: AlertType;
  severity: AlertSeverity;
  status: AlertStatus;
  title: string;
  summary: string;
  explanation: string | null;
  recommended_action: string | null;
  confidence: number | null;
  source: AlertSource;
  ai_generated: boolean;
  assigned_to: string | null;
  assignee_role: UserRole | null;
  auto_escalate: boolean;
  created_at: string;
  updated_at: string;
  resolved_at: string | null;
  metadata: AlertMetadata;
}

export interface AlertMetadata {
  driver_name?: string;
  vehicle_unit?: string;
  load_reference?: string;
  current_location?: string;
  lat?: number;
  lng?: number;
  route_deviation_miles?: number;
  deviation_minutes?: number;
  planned_eta?: string;
  predicted_eta?: string;
  delivery_window_end?: string;
  hos_remaining_minutes?: number;
  eta_required_minutes?: number;
  speed_mph?: number;
  speed_limit_mph?: number;
  idle_duration_minutes?: number;
  geofence_id?: string;
  geofence_name?: string;
  weather_type?: string;
  weather_risk?: 'low' | 'moderate' | 'high' | 'severe';
  maintenance_type?: string;
  miles_until_service?: number;
  inspection_expiry_date?: string;
  days_until_expiry?: number;
  fault_codes?: string[];
  ai_model_version?: string;
  prompt_version?: string;
  dedup_hash?: string;
  dedup_bucket?: string;
  [key: string]: unknown;
}

export interface AlertSignalEvent {
  id: string;
  org_id: string;
  driver_id: string | null;
  vehicle_id: string | null;
  load_id: string | null;
  signal_type: string;
  signal_value: Record<string, unknown>;
  created_at: string;
  processed: boolean;
}

export interface AlertActionLog {
  id: string;
  alert_id: string;
  actor_id: string | null;
  actor_role?: UserRole;
  action_type: ActionType;
  note: string | null;
  created_at: string;
  metadata: Record<string, unknown>;
}

export type ActionType =
  | 'created'
  | 'acknowledged'
  | 'resolved'
  | 'dismissed'
  | 'snoozed'
  | 'escalated'
  | 'reassigned'
  | 'ai_enriched'
  | 'driver_contacted'
  | 'consignee_notified'
  | 'rerouted'
  | 'note_added'
  | 'severity_overridden';

export interface AlertPolicy {
  id: string;
  org_id: string;
  policy_key: PolicyKey;
  policy_value: PolicyValue;
  updated_at: string;
}

export type PolicyKey =
  | 'off_route_threshold_miles'
  | 'off_route_persist_minutes'
  | 'late_eta_threshold_minutes'
  | 'hos_warning_threshold_minutes'
  | 'idle_alert_threshold_minutes'
  | 'speed_threshold_over_limit_mph'
  | 'maintenance_warning_miles'
  | 'inspection_warning_days'
  | 'escalation_timeout_minutes_critical'
  | 'escalation_timeout_minutes_high'
  | 'dedup_window_minutes'
  | 'geofence_exit_grace_minutes';

export type PolicyValue = number | boolean | string | string[];

export interface AlertNotificationQueueItem {
  id: string;
  alert_id: string;
  recipient_user_id: string;
  channel: DeliveryChannel;
  delivery_status: 'pending' | 'sent' | 'failed' | 'skipped';
  retry_count: number;
  scheduled_for: string;
  sent_at: string | null;
  last_error: string | null;
}

// ─── Rules Engine Types ───────────────────────────────────────────────────────

export interface RuleCandidate {
  signal_id: string;
  org_id: string;
  driver_id: string | null;
  vehicle_id: string | null;
  load_id: string | null;
  alert_type: AlertType;
  base_severity: AlertSeverity;
  metadata: AlertMetadata;
  confidence: number;
}

export interface RuleEvaluationContext {
  org_id: string;
  policies: Record<PolicyKey, PolicyValue>;
  driver?: DriverContext;
  vehicle?: VehicleContext;
  load?: LoadContext;
  route?: RouteContext;
  weather?: WeatherContext;
}

export interface DriverContext {
  id: string;
  name: string;
  hos_remaining_minutes: number;
  hours_14_window_remaining: number;
  is_on_duty: boolean;
  current_lat: number;
  current_lng: number;
  speed_mph: number;
  last_ping_at: string;
}

export interface VehicleContext {
  id: string;
  unit_number: string;
  odometer_miles: number;
  last_service_miles: number;
  inspection_expiry: string;
  registration_expiry: string;
  active_fault_codes: string[];
  maintenance_schedule: MaintenanceScheduleItem[];
}

export interface MaintenanceScheduleItem {
  type: string;
  due_at_miles: number;
  last_completed_miles: number;
}

export interface LoadContext {
  id: string;
  reference: string;
  status: string;
  pickup_location: { lat: number; lng: number; address: string };
  delivery_location: { lat: number; lng: number; address: string };
  pickup_window_start: string;
  pickup_window_end: string;
  delivery_window_start: string;
  delivery_window_end: string;
  planned_eta: string;
  live_eta: string;
  rate_usd: number;
}

export interface RouteContext {
  polyline: string;
  planned_corridor_width_miles: number;
  deviation_miles: number;
  deviation_started_at: string | null;
  traffic_delay_minutes: number;
  weather_delay_minutes: number;
}

export interface WeatherContext {
  condition: string;
  severity: 'low' | 'moderate' | 'high' | 'severe';
  advisory_text: string | null;
  affects_route: boolean;
  affected_segment_start_miles: number;
  affected_segment_end_miles: number;
}

// ─── AI Copilot Types ─────────────────────────────────────────────────────────

export interface CopilotInputPayload {
  alert_type: AlertType;
  driver_name: string | null;
  vehicle_unit: string | null;
  load_reference: string | null;
  current_location: string | null;
  planned_eta: string | null;
  predicted_eta: string | null;
  delivery_window_end: string | null;
  hos_remaining_minutes: number | null;
  traffic_delay_minutes: number | null;
  weather_risk: string | null;
  route_deviation_miles: number | null;
  deviation_duration_minutes: number | null;
  speed_mph: number | null;
  speed_limit_mph: number | null;
  idle_duration_minutes: number | null;
  maintenance_type: string | null;
  miles_until_service: number | null;
  inspection_expiry_date: string | null;
  days_until_expiry: number | null;
  geofence_name: string | null;
  dispatcher_notes: string | null;
  recent_events: string[];
}

export interface CopilotOutputPayload {
  severity: AlertSeverity;
  confidence: number;
  title: string;
  summary: string;
  explanation: string;
  recommended_action: string;
  assignee_role: UserRole;
  auto_escalate: boolean;
  secondary_assignees?: UserRole[];
  estimated_resolution_minutes?: number;
  financial_impact_note?: string | null;
}

// ─── Frontend Component Props ─────────────────────────────────────────────────

export interface AlertsInboxProps {
  orgId: string;
  userRole: UserRole;
  userId: string;
  isPremium: boolean;
  onAlertSelect: (alert: AlertEvent) => void;
  selectedAlertId?: string;
}

export interface AlertDetailDrawerProps {
  alert: AlertEvent | null;
  userRole: UserRole;
  isPremium: boolean;
  onAction: (alertId: string, action: ActionType, note?: string) => Promise<void>;
  onClose: () => void;
}

export interface AICopilotCardProps {
  alert: AlertEvent;
  isPremium: boolean;
  onUpgrade: () => void;
}

export interface AlertSeverityBadgeProps {
  severity: AlertSeverity;
  size?: 'sm' | 'md' | 'lg';
  pulse?: boolean;
}

export interface AlertFiltersProps {
  activeFilter: string;
  onFilterChange: (filter: string) => void;
  counts: Record<string, number>;
}

export interface AlertTimelineProps {
  actions: AlertActionLog[];
  alertCreatedAt: string;
}

// ─── Realtime Payload ─────────────────────────────────────────────────────────

export interface RealtimeAlertPayload {
  eventType: 'INSERT' | 'UPDATE' | 'DELETE';
  new: AlertEvent | null;
  old: AlertEvent | null;
  errors: string[] | null;
}
