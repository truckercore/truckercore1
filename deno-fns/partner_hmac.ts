// deno-fns/partner_hmac.ts
// HMAC helper for partner manifest signing: hex SHA-256 with constant-time compare.

function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('')
}

async function hmacHex(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload))
  return toHex(sig)
}

export async function hmacValid(secret: string, payload: string, sigHex: string): Promise<boolean> {
  const expected = await hmacHex(secret, payload)
  if (expected.length !== sigHex.length) return false
  // constant-time compare
  let diff = 0
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ sigHex.charCodeAt(i)
  return diff === 0
}
