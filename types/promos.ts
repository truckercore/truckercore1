// types/promos.ts
// Request/response contracts for Promotions-related APIs, JWT claims, and webhook headers.

export type DiscountType = 'amount' | 'percent';
export type ChannelType = 'qr' | 'code';
export type ParkingStatus = 'open' | 'limited' | 'full' | 'unknown';

export interface PromotionsCreateRequest {
  org_id: string;
  title: string;
  description?: string;
  type: DiscountType;
  value_cents?: number;         // when type = 'amount'
  value_percent?: number;       // when type = 'percent' (0-100)
  start_at: string;             // ISO
  end_at: string;               // ISO
  sku_scope?: Record<string, unknown>;
  min_spend_cents?: number;
  per_user_limit?: { per_day?: number; per_month?: number };
  global_cap?: number;
  hours?: Array<{ dow: 'mon'|'tue'|'wed'|'thu'|'fri'|'sat'|'sun'; from: string; to: string }>;
  channels: ChannelType[];
  locations: string[];
  metadata?: { brand?: string; points_multiplier?: number; [k: string]: unknown };
}
export interface PromotionsCreateResponse {
  promo: {
    id: string;
    org_id: string;
    pos_shortcode: string;
    poster_qr_url: string;
    is_active: boolean;
  };
}

export interface PromotionsNearbyQuery {
  lat: number;
  lng: number;
  radius_mi?: number;
  user_id?: string;
}
export interface PromotionsNearbyItem {
  promo_id: string;
  location_id: string;
  title: string;
  type: DiscountType;
  value_cents?: number;
  value_percent?: number;
  distance_mi: number;
  parking_status: ParkingStatus;
  confidence: number;  // 0-1
  brand?: string;
  badges?: string[];
  channels: ChannelType[];
  score: number;       // relevance score
  factors?: {
    parking?: number; fuel?: number; loyalty?: number; amenities?: number; distance?: number; confidence?: number;
  };
  metadata?: { points_multiplier?: number; [k: string]: unknown };
}
export interface PromotionsNearbyResponse {
  promos: PromotionsNearbyItem[];
}

export interface PromotionsIssueQrRequest {
  promo_id: string;
  location_hint?: string;
  device_hash?: string; // sha256:<hex>
}
export interface PromotionsIssueQrResponse {
  token: string; // JWT
  nonce: string; // base64url
  exp: number;   // unix seconds
}

export interface PromotionsRedeemRequest {
  token: string;
  cashier_id: string;
  subtotal_cents: number;
  location_id: string;
}
export interface PromotionsRedeemResponse {
  approved: boolean;
  discount_cents: number;
  pos_code: string | null;
  redemption_id: string | null;
  reason: string | null;
}

// JWT
export interface PromoJwtClaims {
  iss: 'truckercore.promos';
  sub: string;          // user_id
  promo_id: string;
  nonce: string;        // base64url
  location_hint?: string;
  device_hash?: string; // sha256:<hex>
  iat: number;          // unix seconds
  exp: number;          // unix seconds
}

// Webhook payload + signature header names
export interface PosWebhookPayload {
  event: 'promo.approved';
  redemption_id: string;
  org_id: string;
  location_id: string;
  promo_id: string;
  user_id: string;
  subtotal_cents: number;
  discount_cents: number;
  pos_code: string;
  occurred_at: string; // ISO
}
export interface SignedWebhook {
  'X-Timestamp': string; // ISO
  'X-Signature': string; // sha256=hex(hmac(timestamp + '.' + rawBody))
}
