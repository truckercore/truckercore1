# Phase 1 — Feature 2: Combo Role Support (Carrier + Broker)

Goal: Allow a single account to act as both Carrier and Broker. Store roles as an array in `profiles.roles`, keep `primary_role` for default routing, and propagate both into JWT claims.

## 1) Data Layer — Migration & RLS

Run: `docs/supabase/phase1_combo_roles.sql`
- Adds `profiles.roles jsonb` and backfills from `primary_role`.
- Adds GIN index on `roles`.

RLS Updates (apply per table where role-scoping matters):
- Broker-only data (e.g., broker-posted loads): require `jwt->'app_roles'` contains "broker" and correct org/ownership.
- Carrier-only data: require `jwt->'app_roles'` contains "carrier" (maps to Fleet Manager in app) and correct org/ownership.
- In all cases, enforce org scoping (e.g., `org_id = jwt.app_org_id`).

Example snippet:
```sql
-- Example policy WHERE a broker should see broker-owned loads only
USING (
  auth.uid() = owner_user_id
  AND ((current_setting('request.jwt.claims', true)::jsonb -> 'app_roles') ? 'broker')
  AND (current_setting('request.jwt.claims', true)::jsonb ->> 'app_org_id')::uuid = org_id
)
```

## 2) Billing & JWT Claims

Stripe Plan: `carrier_broker_combo`
- Add plan metadata: `app_roles = ["carrier","broker"]`.

Webhook handler (Stripe → Supabase):
- On subscription created/updated to `carrier_broker_combo`:
  - Update `public.profiles.roles = ['carrier','broker']` for the user (and set `primary_role = 'broker'` by default unless selected otherwise).
- On downgrade to single role:
  - Set `roles` to `[that_role]` and `primary_role` accordingly.

JWT claims: update `custom_access_token_hook` to include:
- `app_roles` from `profiles.roles`
- `app_primary_role` from `profiles.primary_role`
- `app_org_id` for org scoping (if not already present)

Pseudo-code (PL/pgSQL):
```sql
create or replace function auth.custom_access_token_hook(event jsonb)
returns jsonb language plpgsql as $$
DECLARE
  claims jsonb := event;
  prof record;
BEGIN
  select roles, primary_role, org_id into prof from public.profiles where id = (event->>'user_id')::uuid;
  claims := jsonb_set(claims, '{app_roles}', coalesce(to_jsonb(prof.roles), '[]'::jsonb));
  claims := jsonb_set(claims, '{app_primary_role}', to_jsonb(coalesce(prof.primary_role, 'broker')));
  claims := jsonb_set(claims, '{app_org_id}', to_jsonb(prof.org_id));
  return claims;
END;$$;
```

## 3) Application Logic (Flutter)

- The client now uses JWT claims when available:
  - `lib/common/state/roles_from_jwt.dart` decodes `app_roles` and `app_primary_role`.
  - `comboAvailableRolesProvider` prefers JWT roles; fallback to previous heuristic.
  - `currentRoleProvider` keeps selected role in sync with `sessionProvider`.
- Global UI control:
  - `lib/common/widgets/switch_role_menu.dart` renders a dropdown in app bars when multiple roles exist.
  - Integrated into Broker, Carrier (Fleet Manager), Owner-Op, and Driver dashboards.
- Redirect/selection:
  - On first login with multiple roles, prompt the user to choose their default (implement in your auth/onboarding flow or router guard as needed); store to `profiles.primary_role`.

## 4) QA

- Upgrade to combo plan → verify `profiles.roles=['carrier','broker']` and JWT contains both roles.
- Downgrade → `roles` becomes a single element; JWT reflects change in next token refresh.
- UI:
  - Switch role via dropdown → dashboard changes immediately; banner text updates.
  - Log out/in → returns to `primary_role`.
- Security/RLS: confirmed per-table policies block cross-role leaks.

## 5) Observability

Emit events (Edge Function or database trigger):
- `role_switch(user_id, from_role, to_role, at)`
- `combo_plan_upgrade(org_id, user_id, timestamp)`

## Notes

- In this Flutter app, "Carrier" maps to `AppRole.fleetManager` for dashboard selection.
- Ensure your router respects `app_primary_role` on initial navigation.
