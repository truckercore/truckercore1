# Parking / Ads Hardening and Geospatial Support

This migration delivers high‑impact fixes aligned with the checklist:

What’s included (DB)
- Geospatial extensions: `cube` and `earthdistance` enabled so `ll_to_earth/earth_distance` work. Functional GiST indexes are created on `truckstops(lat,lng)` and `parking_stops(lat,lng)` when those tables exist.
- Data constraints:
  - `ads`: `active_to > active_from`; optional radius clamp `[1, 250]`; optional roles subset `roles <@ {'driver','ownerop'}`; optional FK `ads.stop_id -> truckstops(id)`.
  - `parking_status`: non‑negative `available_estimate/available_total`; `confidence` clamped to `[0,1]`.
  - `parking_reports`: when `kind='count'`, `value` must be present and `>= 0`.
- Anti‑spam partial unique indexes on `parking_reports`:
  - unique per minute per `(stop_id, user_id)` when `source='driver'`.
  - unique per minute per `(stop_id, device_hash)` when `device_hash IS NOT NULL`.
- `updated_at` trigger on `ads` using `set_updated_at()`.
- Free vs paid masking:
  - SECURITY DEFINER RPC `parking_status_public_summary(stop_id|lat/lng, radius_km, limit)` returning masked fields: `stop_id, status_bucket, confidence_rounded, last_reported_by/at`.
  - Grants: EXECUTE to `authenticated` and `service_role`; `PUBLIC` revoked; owner set to `app_owner` if present.
- RLS tightening:
  - `ad_impressions` and `ad_clicks`: add SELECT policy for `authenticated` where `user_id = auth.uid()`; rows with NULL user_id are not readable to normal users.
- Performance indexes for ads:
  - Covering index: `(stop_id, active_from, active_to, priority)`.
  - Partial active window: `WHERE now() BETWEEN active_from AND active_to`.
- Observability:
  - `parking_status_audit` table + trigger that logs transitions (estimate/confidence changes) on INSERT/UPDATE.

Why these changes
- Ensures your earthdistance‑backed proximity queries actually use GiST.
- Prevents bad input and spammy writes; protects UX and downstream models.
- Correctly masks parking status for free users without fighting RLS on the base table.
- Tightens privacy on impressions/clicks, avoiding NULL‑user leakage.
- Adds lightweight audit of status transitions for debugging/quality analysis.

How to apply
```
\i supabase/migrations/2025-09-16_parking_ads_hardening.sql
```

Quick verification
- Extensions & indexes:
  - `select extname from pg_extension where extname in ('cube','earthdistance');`
  - `\d+ public.truckstops` and confirm `idx_truckstops_earth` when columns exist.
- Constraints:
  - `insert into ads(active_from, active_to) values (now(), now())` should fail (unless `active_to` is null).
  - `insert into parking_reports(kind,value) values ('count', null)` should fail.
- Anti‑spam:
  - Try two `parking_reports` inserts in the same minute for same `(stop_id, user_id, source='driver')`; second should hit unique index.
- Masked RPC:
  - `select * from public.parking_status_public_summary(null, 40.0, -74.5, 25, 10);`
  - `select * from public.parking_status_public_summary('<stop-uuid>'::uuid, null, null, null, 1);`
- RLS tightening:
  - As a normal user with JWT, attempt to `select * from ad_impressions where user_id is null;` — should return 0 rows (policy blocks).
- Audit:
  - Update a `parking_status` row; `select * from public.parking_status_audit order by at desc limit 5;` shows delta.

Notes
- If you migrate to PostGIS in the future, prefer `geography(Point,4326)` and use `ST_DWithin`/`ST_Distance` for rich spatial operations.
- The anti‑spam interval uses 1‑minute buckets for simplicity; if you want a 10‑minute window, consider a generated column `created_at_10m` that buckets timestamps and then index on it.
- The masked RPC avoids views over RLS‑gated tables; keep it SECURITY DEFINER and document intentional RLS bypass in comments.
