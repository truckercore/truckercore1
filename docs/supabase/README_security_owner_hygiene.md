# Owner/Grant Hygiene (app_owner)

This one-time migration creates a dedicated owner role (app_owner), transfers ownership of sensitive functions/tables, and narrows execution grants.

Why this exists:
- Avoid superuser usage in application code.
- Ensure RPCs only run for authenticated users by default.
- Make RLS bypass an explicit, intentional choice via SECURITY DEFINER with clear documentation.

## What the SQL does
- Creates a NOLOGIN role `app_owner`.
- Transfers ownership of tables if they exist: `dispatch_actions`, `dispatch_safe_staging`, `mobile_offline_queue`, `loads`, `vehicle_positions`.
- Finds functions by name (any signature): `stage_safe_send`, `undo_action`, `confirm_and_apply` and:
  - Sets OWNER to `app_owner`.
  - Marks them `SECURITY DEFINER` and locks `search_path` to `public, pg_temp`.
  - Adds a comment explaining the intentional RLS bypass and to stamp server identity.
  - Revokes `PUBLIC`/`anon` EXECUTE; grants EXECUTE to `authenticated` and `service_role` only.
- Sets default privileges so future functions owned by `app_owner` won’t be executable by `PUBLIC`.

Run it once per environment:

```sql
\i docs/supabase/security_owner_hygiene.sql
```

## Testing checklist mapping
Use `tests/security/security_checks.mjs` as a starting point.

- Calls without a session fail with `AUTH_REQUIRED`:
  - The SQL revokes `PUBLIC` EXECUTE. The test script exercises anonymous RPC call and expects denial.
- Client-supplied `org_id`/`user_id` are ignored; server stamps identity:
  - Ensure function bodies use `auth.uid()`/`jwt.claims`. The test sends bogus values and expects they’re not trusted.
- Dynamic SQL paths reject unknown identifiers:
  - We lock `search_path` at function level to `public, pg_temp`.
- RLS bypass only where intended:
  - Because functions run as `app_owner` (owner of target tables), RLS may be bypassed. This is intentional and documented by a comment. Validate using a low-priv user via the RPC vs direct table access.
- Error messages don’t leak schema details:
  - Adopt app-level codes (e.g., `RAISE ... USING ERRCODE 'P0001', MESSAGE 'AUTH_REQUIRED'`). Keep details in logs, not messages.

## Notes
- If your project uses a different schema than `public`, adjust the script.
- If you use Edge Functions instead of SQL RPC to commit changes, apply similar grant logic to the Edge Function routing (Auth required, service role for back-office).