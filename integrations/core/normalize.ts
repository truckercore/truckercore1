// integrations/core/normalize.ts
import { admin } from "./storage";

type Telemetry = {
  orgId: string;
  provider: string;
  deviceId?: string;
  ts: string;
  lat: number;
  lng: number;
  speedKph?: number;
  meta?: Record<string, unknown>;
};

type Invoice = {
  orgId: string;
  provider: string;
  externalId: string;
  amountCents: number;
  currency?: string;
  status: string;
  issuedAt?: string;
  meta?: Record<string, unknown>;
};

export async function normalizeTelemetry(rows: Telemetry[]) {
  if (!rows.length) return;
  const payload = rows.map((r) => ({
    org_id: r.orgId,
    source_provider: r.provider,
    device_id: r.deviceId ?? null,
    ts: r.ts,
    lat: r.lat,
    lng: r.lng,
    speed_kph: r.speedKph ?? null,
    meta: r.meta ?? {},
  }));
  const { error } = await admin.from("normalized_telemetry").insert(payload);
  if (error) throw error;
}

export async function normalizeInvoices(rows: Invoice[]) {
  if (!rows.length) return;
  const payload = rows.map((r) => ({
    id: crypto.randomUUID(),
    org_id: r.orgId,
    source_provider: r.provider,
    external_id: r.externalId,
    amount_cents: r.amountCents,
    currency: r.currency ?? "USD",
    status: r.status,
    issued_at: r.issuedAt ?? null,
    meta: r.meta ?? {},
  }));
  const { error } = await admin.from("normalized_invoices").insert(payload);
  if (error) throw error;
}
