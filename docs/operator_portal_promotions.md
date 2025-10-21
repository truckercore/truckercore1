# Promotions, QR Checkout, and Promo Codes (MVP)

Scope: Minimal-friction, end-to-end flow for Operators (create/manage, scan) and Drivers (discover, save, redeem).

Environment variables (Edge Functions)
- SUPABASE_URL
- SUPABASE_ANON (preferred; legacy SUPABASE_ANON_KEY supported with a deprecation warning)
- SUPABASE_SERVICE_ROLE_KEY
- PROMO_JWT_SECRET (or SUPABASE_JWT_SECRET)
- PROMO_WEBHOOK_SECRET (optional; for POS webhook signing)
- PROMO_POS_WEBHOOK_URL (optional)
- WEB_URL or DEEPLINK_BASE (for poster_qr_url)

Tables (see docs/supabase/promo_schema.sql)
- promotions, promo_codes, promo_qr_nonce, promo_redemptions, loyalty_wallet (+ optional promo_audit)
- Helper view: v_promo_usage

RLS (see docs/supabase/promo_rls.sql)
- Drivers: can read active promotions via Edge; insert into loyalty_wallet for self.
- Operators: CRUD promotions within org; read redemptions by their locations. Direct writes to `promo_redemptions` are service-only.

API Endpoints (Edge Functions)
- POST /functions/v1/promotions.create (operator)
  Request: { title, desc, type: "percent"|"amount", value_cents, start_at, end_at, sku_scope?, min_spend_cents?, per_user_limit?, per_day_limit?, global_cap?, hours?, channels:["QR"|"code"|...], locations?[location_id], is_active? }
  Response: { id, pos_shortcode, poster_qr_url }

- GET /functions/v1/promotions.nearby?lat&lng&radius_km=25 (driver)
  Response: { ok: true, promos: [{ promo_id, title, description, type, value_cents, channels, distance_km, badges[], factors{} }] }

- POST /functions/v1/promotions.issue_qr (driver)
  Request: { promo_id, device_hash?, location_hint? }
  Response: { token, exp }
  Notes: Token payload = { promo_id, user_id, nonce, location_hint, exp, device_hash }. TTL ~75s; nonces are one-time.

- POST /functions/v1/promotions.redeem (scanner portal)
  Request: { token, cashier_id, subtotal_cents, location_id, pos_ref? }
  Response (approved): { approved: true, discount_cents, pos_code? }
  Response (declined): { approved: false, reason }
  Reasons include: TOKEN_EXPIRED, NONCE_USED, LOCATION_MISMATCH, MIN_SPEND, PER_USER_LIMIT, PER_DAY_LIMIT, GLOBAL_CAP, NO_DISCOUNT.

Optional
- POST /functions/v1/promotions.validate_code (manual POS)
  Request: { promo_code, cashier_id, subtotal_cents, user_id? }
  Response mirrors redeem, without QR nonce.

JWT/HMAC Guidance
- JWT signing: HS256 with PROMO_JWT_SECRET; keep TTL short (30–90s).
- Webhook: include x-signature-hmac-sha256 header = hex(HMAC_SHA256(PROMO_WEBHOOK_SECRET, body)). Verify by recomputing HMAC and comparing in constant time.

Driver UX
- Promos tab lists nearby promos with badges and distances; supports "Add to Wallet" (loyalty_wallet insert) and "Redeem" (promotions.issue_qr) with a countdown.
- Saved Wallet shows active promos; falls back to static code display when channels include code.

Operator UX
- Create/Edit Promotion form (fields above), publish to get poster QR and deep link.
- Scanner page: camera view + result panel with Approved/Declined, reason, discount, and POS code (pos_shortcode).

Analytics
- Use `v_promo_usage` for basic counts. A simple CSV export can be added mirroring export_acct_csv pattern.

Security Notes
- Nonce is one-time and short-lived; invalidated on first redeem attempt.
- Enforce per-user/day/global caps server-side only.
- Bind device via device_hash in token and redemption row; require match when provided.
- Scanner portal must be authenticated as an operator; location_id must be within operator scope.

Examples
- Create (operator):
  curl -s -X POST -H "Authorization: Bearer $OPERATOR_JWT" -H "Content-Type: application/json" \
    -d '{"title":"10% off Diesel","type":"percent","value_cents":1000,"start_at":"2025-09-19T00:00:00Z","end_at":"2025-12-31T23:59:59Z","channels":["QR","code"],"min_spend_cents":5000}' \
    "$FUNCTIONS_URL/promotions.create"

- Nearby (driver):
  curl -s "$FUNCTIONS_URL/promotions.nearby?lat=41.65&lng=-83.53&radius_km=50" | jq .

- Issue QR (driver):
  curl -s -X POST -H "Authorization: Bearer $DRIVER_JWT" -H "Content-Type: application/json" \
    -d '{"promo_id":1,"device_hash":"abc123"}' "$FUNCTIONS_URL/promotions.issue_qr"

- Redeem (scanner):
  curl -s -X POST -H "Authorization: Bearer $OPERATOR_JWT" -H "Content-Type: application/json" \
    -d '{"token":"<from_issue_qr>","cashier_id":"C-77","subtotal_cents":12000,"location_id":"<uuid>"}' \
    "$FUNCTIONS_URL/promotions.redeem" | jq .
