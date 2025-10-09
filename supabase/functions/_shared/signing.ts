import { HmacSha256 } from "https://deno.land/std@0.224.0/crypto/hmac.ts";

export async function verifySignature(req: Request, secret: string): Promise<void> {
  const ts = req.headers.get("X-Timestamp");
  const sig = req.headers.get("X-Signature");
  if (!ts || !sig) throw new Error("Missing signature headers");

  const skew = Math.abs(Date.now() - Date.parse(ts));
  if (skew > 5 * 60 * 1000) throw new Error("Signature expired");

  const url = new URL(req.url);
  const body = await req.clone().text();
  const payload = `${ts}|${url.pathname}|${body}`;
  const h = new HmacSha256(secret);
  const mac = await h.update(new TextEncoder().encode(payload)).digest();
  const expected = Array.from(new Uint8Array(mac)).map(b=>b.toString(16).padStart(2,"0")).join("");
  if (expected !== sig) throw new Error("Invalid signature");
}
