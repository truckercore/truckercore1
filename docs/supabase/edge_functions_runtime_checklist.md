# Edge Functions Runtime Checklist

This checklist ensures all Supabase Edge Functions can connect to your database and pass the readiness checks.

Project reference: viqrwlzdtosxjzjvtxnr
Project URL: https://viqrwlzdtosxjzjvtxnr.supabase.co

Required environment variables (set for every deployed Edge Function):
- SUPABASE_URL = https://<your-supabase-project>.supabase.co
- SUPABASE_SERVICE_ROLE_KEY = <service_role_key>

Recommended for public endpoints:
- INTEGRATIONS_SIGNING_SECRET  # used to validate X-Signature = sha256(secret + '.' + rawBody)
- RATE_LIMIT_MAX_RPS, RATE_LIMIT_BURST, RATE_LIMIT_WINDOW_MS  # if you enforce rate limits

How to set secrets with Supabase CLI (per function):
1) Authenticate and target the project
   supabase login
   supabase link --project-ref viqrwlzdtosxjzjvtxnr

2) Set required secrets for the function runtime
   supabase secrets set \
     SUPABASE_URL=https://viqrwlzdtosxjzjvtxnr.supabase.co \
     SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY \
     INTEGRATIONS_SIGNING_SECRET=YOUR_SIGNING_SECRET

3) Deploy functions
   supabase functions deploy integrations_push_load
   supabase functions deploy integrations_add_calendar_event
   supabase functions deploy quickbooks_export_invoice
   supabase functions deploy keys_create
   supabase functions deploy negotiation_suggest_counter
   supabase functions deploy alerts_evaluate_watchlists
   supabase functions deploy compliance_validate_candidate
   supabase functions deploy negotiation_counter
   supabase functions deploy delay_predict
   supabase functions deploy tms_sync_loads
   supabase functions deploy acct_export_bookings
   supabase functions deploy comms_send
   supabase functions deploy calendar_sync_events

Notes for hosted platforms (e.g., Vercel):
- Add the same environment variables in your platform UI for the function runtime (both Production and Preview environments).
- Redeploy or restart the functions after updating environment variables so they take effect.

Readiness verification
- Re-run your readiness query or smoke tests after setting secrets. Remaining items should flip to ok: true.
- Confirm each function can connect to Supabase by invoking it with a minimal payload and verifying a 200 response (or expected 401 for endpoints requiring X-Signature until you provide a valid signature).

Signing requests (for public endpoints)
- Compute X-Signature as sha256(INTEGRATIONS_SIGNING_SECRET + '.' + rawBody)
- Provide the exact raw JSON body used to compute the signature.

Idempotency
- Where applicable, send x-idem-key header or body.idem to dedupe repeated requests. Functions using connector_jobs will return duplicated: true for matching idem values.


# Additional deploy commands for new functions (status_get, report_problem, ab_assign, health_ping)
# Run after linking your project (viqrwlzdtosxjzjvtxnr)
# supabase functions deploy <name>
- supabase functions deploy status_get
- supabase functions deploy report_problem
- supabase functions deploy ab_assign
- supabase functions deploy health_ping
