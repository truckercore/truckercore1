import { HmacSha256 } from "https://deno.land/std@0.224.0/crypto/hmac.ts";

export async function verifySignedRequest(req: Request, secret: string) {
  const ts = req.headers.get("X-Timestamp");
  const sig = req.headers.get("X-Signature");
  if (!ts || !sig) throw new Error("Missing signature headers");
  const skew = Math.abs(Date.now() - Date.parse(ts));
  if (skew > 5 * 60 * 1000) throw new Error("Signature expired");

  const path = new URL(req.url).pathname;
  const body = await req.clone().text();
  const payload = `${ts}|${path}|${body}`;
  const mac = new HmacSha256(secret);
  const digest = await mac.update(new TextEncoder().encode(payload)).digest();
  const expected = Array.from(new Uint8Array(digest)).map(b=>b.toString(16).padStart(2,'0')).join('');
  if (expected !== sig) throw new Error("Invalid signature");
}
