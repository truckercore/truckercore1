# Fleet Drivers API (Edge Functions)

Endpoints
- POST /functions/v1/fleet.drivers.create
  Body: { org_id, name, email?, phone?, license_no?, truck_id?, role }
  Returns: { user_id, driver_id, status }

- POST /functions/v1/fleet.drivers.invite
  Body: { org_id, email_or_phone, role: 'driver'|'dispatcher'|'safety', send_via: 'email'|'sms' }
  Returns: { invite_id, token, status }

- POST /functions/v1/fleet.drivers.bulk_upload
  Body: { org_id, rows: [{ name, email?, phone?, license_no?, truck_id?, role }...], dry_run?: boolean }
  Returns: { accepted, rejected: [{ row, reason }] }

- POST /functions/v1/fleet.invites.accept
  Body: { token }
  Returns: { user_id, org_id, role, auth_hint }

Curl examples
```
# Create driver (manager)
curl -X POST "$SUPABASE_URL/functions/v1/fleet.drivers.create" \
  -H "Authorization: Bearer $MANAGER_JWT" \
  -H 'content-type: application/json' \
  -d '{"org_id":"ORG","name":"Jane Driver","email":"jane@example.com","role":"driver"}'

# Send invite
curl -X POST "$SUPABASE_URL/functions/v1/fleet.drivers.invite" \
  -H "Authorization: Bearer $MANAGER_JWT" \
  -H 'content-type: application/json' \
  -d '{"org_id":"ORG","email_or_phone":"+15551234567","role":"driver","send_via":"sms"}'

# Bulk upload (dry run)
curl -X POST "$SUPABASE_URL/functions/v1/fleet.drivers.bulk_upload" \
  -H "Authorization: Bearer $MANAGER_JWT" \
  -H 'content-type: application/json' \
  -d '{"org_id":"ORG","dry_run":true,"rows":[{"name":"A","email":"a@x.com","role":"driver"},{"name":"B","phone":"+15550001111","role":"driver"}]}'

# Accept invite (driver mobile)
curl -X POST "$SUPABASE_URL/functions/v1/fleet.invites.accept" \
  -H "Authorization: Bearer $DRIVER_JWT" \
  -H 'content-type: application/json' \
  -d '{"token":"<invite-token>"}'
```

Notes
- RLS: See docs/supabase/fleet_core_schema.sql. Accept invite uses SECURITY DEFINER RPC.
- Billing hooks: add seat increment/decrement on activation/suspension.
- Throttling: basic rate limit on invites per org.
