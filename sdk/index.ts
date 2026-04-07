// sdk/index.ts
import crypto from 'crypto';

export type ClientOptions = {
  baseUrl: string;
  apiKey: string; // org-scoped key
  orgId?: string; // optional, set X-Org-Id if needed
  fetchImpl?: typeof fetch; // allow environment injection
};

export class TruckerCoreClient {
  private baseUrl: string;
  private apiKey: string;
  private orgId?: string;
  private f: typeof fetch;

  constructor(opts: ClientOptions) {
    this.baseUrl = opts.baseUrl.replace(/\/+$/, '');
    this.apiKey = opts.apiKey;
    this.orgId = opts.orgId;
    // @ts-ignore Node 18+ has global fetch; allow injection
    this.f = (opts.fetchImpl ?? (globalThis as any).fetch) as typeof fetch;
    if (!this.f) {
      throw new Error('No fetch implementation available. Provide fetchImpl in ClientOptions.');
    }
  }

  private headers(extra?: Record<string, string>) {
    return {
      'Content-Type': 'application/json',
      'X-Api-Key': this.apiKey,
      ...(this.orgId ? { 'X-Org-Id': this.orgId } : {}),
      ...(extra ?? {}),
    };
  }

  // Example endpoints. Add others as needed.
  async listLoads(orgId?: string) {
    const url = `${this.baseUrl}/v1/orgs/${orgId ?? this.orgId}/loads`;
    const res = await this.f(url, { method: 'GET', headers: this.headers() });
    if (!res.ok) throw new Error(`listLoads failed: ${res.status}`);
    return res.json();
  }

  async createDocument(formData: FormData, orgId?: string, idemKey?: string) {
    const url = `${this.baseUrl}/v1/orgs/${orgId ?? this.orgId}/documents`;
    const headers: Record<string, string> = { 'X-Api-Key': this.apiKey };
    if (this.orgId) headers['X-Org-Id'] = this.orgId;
    if (idemKey) headers['Idempotency-Key'] = idemKey;
    const res = await this.f(url, { method: 'POST', headers, body: formData as any });
    if (!res.ok) throw new Error(`createDocument failed: ${res.status}`);
    return res.json();
  }

  async createWebhookSubscription(input: { name: string; endpoint_url: string; topics: string[] }, orgId?: string, idemKey?: string) {
    const url = `${this.baseUrl}/v1/orgs/${orgId ?? this.orgId}/webhooks`;
    const res = await this.f(url, {
      method: 'POST',
      headers: this.headers(idemKey ? { 'Idempotency-Key': idemKey } : undefined),
      body: JSON.stringify(input),
    });
    if (!res.ok) throw new Error(`createWebhookSubscription failed: ${res.status}`);
    return res.json();
  }

  async rotateWebhookSecret(id: string, body: { secret_next: string; overlap_minutes?: number }, orgId?: string, idemKey?: string) {
    const url = `${this.baseUrl}/v1/orgs/${orgId ?? this.orgId}/webhooks/${id}/rotate-secret`;
    const res = await this.f(url, {
      method: 'POST',
      headers: this.headers(idemKey ? { 'Idempotency-Key': idemKey } : undefined),
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`rotateWebhookSecret failed: ${res.status}`);
    return res.json();
  }
}

// Webhook signature verification helper
export function verifyWebhookSignature(params: {
  secret: string;
  timestamp: string; // header X-TruckerCore-Timestamp
  bodyRaw: string; // raw JSON string
  signature: string; // header X-TruckerCore-Signature
  maxSkewSec?: number; // default 300
}) {
  const { secret, timestamp, bodyRaw, signature, maxSkewSec = 300 } = params;
  const now = Math.floor(Date.now() / 1000);
  const ts = parseInt(timestamp, 10);
  if (!Number.isFinite(ts) || Math.abs(now - ts) > maxSkewSec) return false;
  const expectedHex = crypto.createHmac('sha256', secret).update(`${timestamp}.${bodyRaw}`).digest('hex');
  // Accept either bare hex or prefixed with sha256=
  const expectedA = Buffer.from(expectedHex);
  const expectedB = Buffer.from(`sha256=${expectedHex}`);
  const got = Buffer.from(signature);
  try {
    return (got.length === expectedA.length && crypto.timingSafeEqual(expectedA, got)) ||
           (got.length === expectedB.length && crypto.timingSafeEqual(expectedB, got));
  } catch {
    return false;
  }
}
