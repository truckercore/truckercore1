// TypeScript
export async function verifySignature(body: string, sig: string, secret: string): Promise<boolean> {
  if (!secret) return false;
  try {
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"]
    );
    const mac = await crypto.subtle.sign("HMAC", key, enc.encode(body));
    const hex = [...new Uint8Array(mac)].map(b => b.toString(16).padStart(2,"0")).join("");
    return sig === hex;
  } catch {
    return false;
  }
}
