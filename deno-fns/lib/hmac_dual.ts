// deno-fns/lib/hmac_dual.ts
// Dual-key HMAC verification utilities for manifest ingestion.

function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('')
}

export async function signHmacHex(body: string, keyBytes: Uint8Array): Promise<string> {
  const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body))
  return toHex(sig)
}

function timingSafeEqHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

export type OrgKey = { kid: string; key_bytes: Uint8Array; active: boolean; next_window: boolean }
export type VerifyResult = { ok: true; kid: string } | { ok: false; reason: string; kid?: string }

export async function verifyDualKeys(
  body: string,
  providedSigHex: string,
  providedKid: string | undefined,
  keys: OrgKey[],
): Promise<VerifyResult> {
  // prefer matching kid; else try active/next in order
  const candidates: OrgKey[] = []
  if (providedKid) candidates.push(...keys.filter(k => k.kid === providedKid))
  candidates.push(...keys.filter(k => k.active))
  candidates.push(...keys.filter(k => k.next_window))

  const tried = new Set<string>()
  for (const k of candidates) {
    if (tried.has(k.kid)) continue
    tried.add(k.kid)
    const sig = await signHmacHex(body, k.key_bytes)
    if (timingSafeEqHex(sig, providedSigHex)) {
      return { ok: true, kid: k.kid }
    }
  }
  return { ok: false, reason: 'bad_hmac', kid: providedKid }
}
