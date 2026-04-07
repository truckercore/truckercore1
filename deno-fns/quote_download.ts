// deno-fns/quote_download.ts
// Endpoint: /api/quotes/download_link?org_id=...&quote_id=...
// Returns a short-lived signed link to /download with a token; rate-limited per org (fixed window).
import { createHmac } from "node:crypto";

const SECRET = Deno.env.get("SIGNED_URL_SECRET") ?? "change-me";
const BUCKET: Record<string, { count: number; ts: number }> = {};
const WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const LIMIT = 60; // per window per org

function rateLimit(key: string) {
  const now = Date.now();
  const b = BUCKET[key] ?? { count: 0, ts: now };
  if (now - b.ts > WINDOW_MS) { b.count = 0; b.ts = now; }
  b.count += 1;
  BUCKET[key] = b;
  if (b.count > LIMIT) throw new Error("rate_limited");
}

function sign(payload: any, ttlSec = 300) {
  const exp = Math.floor(Date.now() / 1000) + ttlSec;
  const b64 = btoa(JSON.stringify({ ...payload, exp }));
  const mac = createHmac("sha256", SECRET).update(b64).digest("base64url");
  return `${b64}.${mac}`;
}

Deno.serve((req) => {
  try {
    const u = new URL(req.url);
    const org = u.searchParams.get("org_id") ?? "anon";
    const quoteId = u.searchParams.get("quote_id");
    if (!quoteId) return new Response("quote_id required", { status: 400 });

    rateLimit(`quote:${org}`);

    // Create a token that encodes a download path specific to the quote (placeholder path)
    const path = `/reports/quotes/${quoteId}.pdf`;
    const token = sign({ p: path, org, q: quoteId }, 300);

    return new Response(JSON.stringify({ url: `/download?token=${encodeURIComponent(token)}` }), { headers: { "content-type": "application/json" } });
  } catch (e) {
    const msg = (e as any)?.message || String(e);
    const status = msg === "rate_limited" ? 429 : 400;
    return new Response(msg, { status });
  }
});
