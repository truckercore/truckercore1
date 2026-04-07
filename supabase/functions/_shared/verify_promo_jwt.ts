// supabase/functions/_shared/verify_promo_jwt.ts
// JWT verification helper for promo QR tokens
// Implements HS256 verification with issuer + 5s clock tolerance per spec.

import jwt from "npm:jsonwebtoken";

const SECRET = Deno.env.get("SECRET_PROMO_JWT_HS256") || Deno.env.get("PROMO_JWT_SECRET") || Deno.env.get("SUPABASE_JWT_SECRET");
if (!SECRET) {
  throw new Error("Missing SECRET_PROMO_JWT_HS256 (or PROMO_JWT_SECRET/SUPABASE_JWT_SECRET fallback)");
}

export interface PromoJwtClaims {
  iss: "truckercore.promos";
  sub: string;
  promo_id: string | number;
  nonce: string;
  location_hint?: string;
  device_hash?: string;
  iat: number;
  exp: number;
}

export function verifyPromoJwt(token: string): PromoJwtClaims {
  const decoded = jwt.verify(token, SECRET as string, {
    algorithms: ["HS256"],
    issuer: "truckercore.promos",
    clockTolerance: 5,
  }) as jwt.JwtPayload;

  const { iss, sub, promo_id, nonce, location_hint, device_hash, iat, exp } = decoded as any;
  if (!sub || !promo_id || !nonce || !exp) {
    throw new Error("invalid_claims");
  }
  return { iss, sub, promo_id, nonce, location_hint, device_hash, iat, exp } as PromoJwtClaims;
}
