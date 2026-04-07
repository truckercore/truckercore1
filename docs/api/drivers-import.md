# Drivers Import & Invites API

These endpoints support CSV validation (dry run), commit with invite creation, and single create/invite/accept flows for drivers and staff.

Auth headers
- x-user-id: UUID of the acting manager (required for create/invite/commit). Manager must have role admin/dispatcher/safety in fleet_members for the org.
- Authorization: Bearer <jwt> is not required for these minimal endpoints, but may be used in other functions.

CSV headers (expected)
name,email,phone,role,license_no,truck_id

Shared validation
- Email format: basic RFC5322-light
- Phone format: E.164 (e.g., +15551234567)
- Role: one of driver|dispatcher|safety|admin
- License #: 3–32 chars (optional)
- Truck ID: UUID-like (optional)

Error codes (selected)
- 400 invalid_json | invalid_request | missing_required | missing_contact
- 401 auth_required (where applicable)
- 403 forbidden
- 409 duplicate_contact_existing | already_processed
- 422 invalid_email_format | invalid_phone_format | invalid_role

Endpoints
- POST /functions/v1/drivers.csv.dryrun
  Body: { csv: string } | { rows: Array<Record<string, unknown>> }
  Returns: { accepted: number; rejected: Array<{ index:number; row:ValidatedRow; errors:string[] }>; rows: ValidatedRow[] }

- POST /functions/v1/drivers.csv.commit
  Headers: x-user-id
  Body: { org_id: string; csv?: string; rows?: Array<Record<string, unknown>>; dryRun?: boolean }
  Returns (dryRun default true): { created: number; rejected: Array<{ index:number; row:ValidatedRow; errors:string[] }>; invites: Array<{ index:number; invite_id:string; token:string }> }

- POST /functions/v1/drivers.create
  Headers: x-user-id
  Body: { org_id: string; name: string; email?: string; phone?: string; role?: 'driver'|'dispatcher'|'safety'|'admin'; license_no?: string; truck_id?: string }
  Returns: { invite_id: string; token: string; status: 'sent' }

- POST /functions/v1/drivers.invite
  Headers: x-user-id
  Body: { org_id: string; email_or_phone: string; role?: 'driver'|'dispatcher'|'safety'|'admin' }
  Returns: { invite_id: string; token: string; status: 'sent' }

- POST /functions/v1/drivers.accept
  Body: { token: string; user_id: string }
  Returns: { org_id: string; role: string; status: 'accepted' }

Curl examples
```
# Dry-run CSV
curl -sS -X POST "$SUPABASE_URL/functions/v1/drivers.csv.dryrun" \
  -H 'content-type: application/json' \
  -d '{"csv":"name,email,phone,role\nJane Driver,jane@example.com,,driver\nJohn Ops,,+15550001111,dispatcher"}'

# Commit (create invites)
curl -sS -X POST "$SUPABASE_URL/functions/v1/drivers.csv.commit" \
  -H "x-user-id: $MANAGER_USER_ID" \
  -H 'content-type: application/json' \
  -d '{"org_id":"ORG-UUID","dryRun":false,"rows":[{"name":"Jane","email":"jane@example.com","role":"driver"}]}'

# Create single invite
curl -sS -X POST "$SUPABASE_URL/functions/v1/drivers.create" \
  -H "x-user-id: $MANAGER_USER_ID" \
  -H 'content-type: application/json' \
  -d '{"org_id":"ORG-UUID","name":"Jane","email":"jane@example.com","role":"driver"}'

# Invite via email or phone
curl -sS -X POST "$SUPABASE_URL/functions/v1/drivers.invite" \
  -H "x-user-id: $MANAGER_USER_ID" \
  -H 'content-type: application/json' \
  -d '{"org_id":"ORG-UUID","email_or_phone":"+15551234567","role":"driver"}'

# Accept invite
curl -sS -X POST "$SUPABASE_URL/functions/v1/drivers.accept" \
  -H 'content-type: application/json' \
  -d '{"token":"<invite-token>","user_id":"<auth-user-id>"}'
```

Smoke tests (manual)
- Dry-run: valid CSV with mixed email/phone → accepted == row count; rejected == []
- Dry-run: invalid email/phone → rejected contains appropriate error codes
- Dry-run: duplicate within file → duplicate_contact_in_file
- Create/Invite: valid request with org role → 200 with token
- Create/Invite: duplicate existing contact in org → 409
- Create/Invite: missing contact → 400
- Accept: valid token → accepted and membership upserted
- Accept: reuse token → 409 already_processed

Env/config
- Required: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
- Optional: INVITE_SEND_WEBHOOK (future), RATE_LIMIT configs
