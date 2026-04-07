// types/events.ts
// Contracts for GPS samples, POI reports, votes, and aggregate responses.

export type GpsSource = 'mobile' | 'sdk';

export interface GpsSample {
  lat: number;
  lng: number;
  speed_kph?: number;
  heading_deg?: number;
  accuracy_m?: number;
  source?: GpsSource; // default 'mobile'
  ts?: string; // ISO, optional (server will default to now())
}

export interface GpsIngestRequest {
  org_id?: string; // optional tenant context
  samples: GpsSample[]; // batched (10–20)
  coarse?: boolean;     // privacy: round lat/lng (~50–100m)
}
export interface GpsIngestResponse { ok: true; accepted: number; skipped: number }

export type PoiKind = 'parking' | 'weigh' | 'incident' | 'fuel';

export interface PoiReportRequest {
  poi_id: string;
  kind: PoiKind;
  status?: string; // parking: open/some/full; weigh: open/closed/bypass
  payload?: Record<string, unknown>; // price, severity, notes
  photo_url?: string;
  lat?: number;
  lng?: number;
}
export interface PoiReportResponse { id: string; trust_snapshot: number; ts: string }

export interface VoteRequest { report_id: string; vote: -1 | 1 }
export interface VoteResponse { ok: true; up: number; down: number }

export interface ParkingStateRow {
  poi_id: string;
  occupancy: 'open' | 'some' | 'full' | 'unknown';
  confidence: number;
  last_update: string;
  source_mix: Record<string, unknown>;
}

export interface WeighStateRow {
  poi_id: string;
  status: 'open' | 'closed' | 'bypass' | 'unknown';
  confidence: number;
  last_update: string;
  source_mix: Record<string, unknown>;
}
