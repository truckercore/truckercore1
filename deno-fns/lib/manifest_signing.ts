// deno-fns/lib/manifest_signing.ts
// HMAC signing/verification helpers for admin manifests.
import { hmacSignHex, hmacVerifyHex } from "./hmac.ts";

export async function signManifest(secret: string, manifest: Record<string, unknown>) {
  const text = JSON.stringify(manifest);
  const sig = await hmacSignHex(secret, text);
  return { manifest, manifest_sig: sig };
}

export async function verifyManifest(secret: string, manifest: Record<string, unknown>, sig: string) {
  return hmacVerifyHex(secret, JSON.stringify(manifest), sig);
}
