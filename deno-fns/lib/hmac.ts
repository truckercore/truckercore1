// deno-fns/lib/hmac.ts
// HMAC-SHA256 sign/verify helpers with hex output and constant-time compare.

function toHex(buf: ArrayBuffer) {
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join("");
}

export async function hmacSignHex(secret: string, payloadText: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payloadText));
  return toHex(sig);
}

export async function hmacVerifyHex(secret: string, payloadText: string, sigHex: string): Promise<boolean> {
  const expected = await hmacSignHex(secret, payloadText);
  // constant-time compare
  if (expected.length !== sigHex.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ sigHex.charCodeAt(i);
  return diff === 0;
}
