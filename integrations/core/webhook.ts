// integrations/core/webhook.ts
import crypto from "crypto";

export function verifyHmacSHA256(body: string, signature: string, secret: string): boolean {
  if (!secret || !signature) return false;
  const mac = crypto.createHmac("sha256", secret).update(body, "utf8").digest("hex");
  try {
    return crypto.timingSafeEqual(Buffer.from(mac), Buffer.from(signature));
  } catch {
    return false;
  }
}
