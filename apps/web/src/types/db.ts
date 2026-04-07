// Typed models to mirror core tables/views we reference.
// Keep minimal, accurate columns for compile-time safety; extend as needed.

export type Load = {
  id: string
  assigned_driver_id: string | null
  origin_city?: string | null
  destination_city?: string | null
  broker_id?: string | null
}

export type MarketRateDaily = {
  id: string
  origin: string
  destination: string
  equipment?: string | null
  service_date?: string | null
  p50: number | null
  p80: number | null
}

export type BrokerCredit = {
  broker_id: string
  tier: 'A' | 'B' | 'C' | null
  d2p_days?: number | null
  bond_ok?: boolean | null
  insurance_ok?: boolean | null
  updated_at?: string | null
}

export type QuoteEvent = {
  id: string
  created_at?: string
  load_id?: string | null
  broker_id?: string | null
  type: string // e.g., 'offer_submitted'
}

export type MarketplaceLoad = {
  id: string
  status: 'open' | 'tendered' | 'covered' | 'cancelled'
  origin: string
  destination: string
  equipment?: string | null
}

export type MarketplaceOffer = {
  id: string
  load_id: string
  carrier_id?: string | null
  price: number
  created_at?: string
}

export type HOSLog = {
  id: string
  driver_id: string
  started_at: string
  ended_at?: string | null
  // Align with DB statuses
  status: 'off' | 'sleeper' | 'driving' | 'on'
}

export type HOSSegment = {
  id: string
  driver_id: string
  start_time: string
  end_time?: string | null
  kind: 'driving' | 'on_duty' | 'off_duty' | 'sleeper'
}

export type SafetyEvent = {
  id: string
  driver_id: string
  occurred_at: string
  type: string
  severity?: string | null
}

export type SafetyCoaching = {
  id: string
  driver_id: string
  created_at?: string
  note: string
}

export type SafetyScore = {
  driver_id: string
  score: number
  updated_at?: string
}

export type VehicleMetric = {
  id: string
  truck_id: string
  ts: string
  fuel_rate?: number | null
  idle_minutes?: number | null
}

export type VehicleMetricsHourly = {
  truck_id: string
  hour: string
  fuel_rate_avg?: number | null
  idle_minutes_sum?: number | null
}

export type ShipmentMilestone = {
  id: string
  shipment_id: string
  code: string // e.g., PICKED_UP, DELIVERED, DELAYED, ETA_UPDATE
  occurred_at: string
}

export type Appointment = {
  id: string
  shipment_id: string
  facility_id?: string | null
  starts_at: string
  ends_at?: string | null
}

export type Invoice = {
  id: string
  created_at?: string
  status: 'draft' | 'sent' | 'paid' | 'void'
  load_id?: string | null
}

export type FeatureFlag = {
  key: string
  enabled: boolean
}

export type OwnerOpExpense = {
  id: string
  driver_id: string
  load_id?: string | null
  category: 'fuel' | 'toll' | 'repair' | 'insurance' | 'other'
  amount_usd: number
  miles?: number | null
  occurred_at?: string | null
  note?: string | null
}
