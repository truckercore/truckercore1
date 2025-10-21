// apps/web/src/lib/integrations/sdk.ts
import crypto from "crypto";

export type OAuthToken = {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  scope?: string;
  token_type?: string;
  obtained_at: number;
};

export type ConnectorContext = {
  orgId: string;
  provider: string; // samsara|geotab|motive|verizon|qbo|comdata|efs|tms_generic|truckcloud
  baseUrl?: string;
  clientId?: string;
  clientSecret?: string;
  webhookSecret?: string;
  apiKey?: string;
};

export function validateSignature(rawBody: string, headerSig: string | null, secret: string): boolean {
  if (!headerSig || !secret) return false;
  const hmac = crypto.createHmac("sha256", secret);
  hmac.update(rawBody, "utf8");
  const digest = hmac.digest("hex");
  try {
    return crypto.timingSafeEqual(Buffer.from(digest), Buffer.from(headerSig));
  } catch {
    return false;
  }
}

export async function ensureIdempotent(key: string, provider: string, orgId: string) {
  const url = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/rpc/mark_idempotent`;
  const body = { p_key: key, p_provider: provider, p_org: orgId } as any;
  const r = await fetch(url, {
    method: "POST",
    headers: {
      apikey: process.env.SUPABASE_SERVICE_ROLE_KEY as string,
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "params=single-object",
    },
    body: JSON.stringify(body),
  });
  if (!r.ok) {
    const txt = await r.text();
    throw new Error(`idempotency rpc failed: ${r.status} ${txt}`);
  }
  const ok = await r.json();
  return !!ok;
}

export function isExpired(token?: OAuthToken) {
  if (!token?.expires_in) return false;
  const now = Date.now();
  return now >= token.obtained_at + (token.expires_in - 60) * 1000; // 60s skew
}

export async function oauthTokenExchange(opts: {
  provider: string;
  tokenUrl: string;
  code: string;
  redirectUri: string;
  clientId: string;
  clientSecret: string;
}) {
  const params = new URLSearchParams({
    grant_type: "authorization_code",
    code: opts.code,
    redirect_uri: opts.redirectUri,
    client_id: opts.clientId,
    client_secret: opts.clientSecret,
  });
  const r = await fetch(opts.tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });
  if (!r.ok) throw new Error(`token exchange failed: ${r.status} ${await r.text()}`);
  const json = await r.json();
  const token: OAuthToken = {
    access_token: json.access_token,
    refresh_token: json.refresh_token,
    expires_in: json.expires_in,
    scope: json.scope,
    token_type: json.token_type,
    obtained_at: Date.now(),
  };
  return token;
}

export async function oauthRefresh(opts: {
  tokenUrl: string;
  refreshToken: string;
  clientId: string;
  clientSecret: string;
}) {
  const params = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: opts.refreshToken,
    client_id: opts.clientId,
    client_secret: opts.clientSecret,
  });
  const r = await fetch(opts.tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: params.toString(),
  });
  if (!r.ok) throw new Error(`refresh failed: ${r.status} ${await r.text()}`);
  const json = await r.json();
  const token: OAuthToken = {
    access_token: json.access_token,
    refresh_token: json.refresh_token ?? opts.refreshToken,
    expires_in: json.expires_in,
    scope: json.scope,
    token_type: json.token_type,
    obtained_at: Date.now(),
  };
  return token;
}
