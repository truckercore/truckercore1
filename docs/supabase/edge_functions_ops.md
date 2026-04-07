# Edge Functions: Deploy, Invoke, Schedule

This guide captures the operational steps to deploy, manually invoke, and schedule the Edge Functions used by this project.

Functions covered
- org_queue_worker
- admin_diagnostics_json
- synthetic_load

Prerequisites
- Supabase CLI installed and authenticated (optional; you can also use curl/HTTP)
- Environment variables available when invoking over HTTP:
  - SUPABASE_SERVICE_ROLE_KEY (for functions that require service-role; pass as Authorization: Bearer ...)

Deploy (CLI)
```
supabase functions deploy org_queue_worker
supabase functions deploy admin_diagnostics_json
supabase functions deploy synthetic_load
```

Manual invocation (CLI)
```
supabase functions invoke org_queue_worker
supabase functions invoke admin_diagnostics_json
supabase functions invoke synthetic_load --query 'drivers=100&hours=24&chunk=2000'
```

HTTP invocation (no CLI)
Replace <project-ref> with your Supabase project ref (e.g., abcdefghijklmnxzy). Include the service role key header if required.

- org_queue_worker:
```
curl -s https://<project-ref>.functions.supabase.co/org_queue_worker \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```
- admin_diagnostics_json:
```
curl -s https://<project-ref>.functions.supabase.co/admin_diagnostics_json \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```
- synthetic_load (with query params):
```
curl -s "https://<project-ref>.functions.supabase.co/synthetic_load?drivers=100&hours=24&chunk=2000" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
```

Windows PowerShell example
```
$funcUrl = "https://<project-ref>.functions.supabase.co"
$hdr = @{ Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY" }
Invoke-RestMethod -Method POST -Uri "$funcUrl/org_queue_worker" -Headers $hdr
Invoke-RestMethod -Method GET  -Uri "$funcUrl/admin_diagnostics_json" -Headers $hdr
Invoke-RestMethod -Method GET  -Uri "$funcUrl/synthetic_load?drivers=100&hours=24&chunk=2000" -Headers $hdr
```

Scheduling (Supabase Dashboard → Edge Functions → Scheduled Triggers)
- org_queue_worker: every 1–2 minutes
- summarize_hos_daily: daily (either pg_cron SQL schedule or a small Edge function that calls the SQL function)
- prune_old_payloads: daily
- raise_alarm_if_overload: every 5 minutes

Quick SQL sanity checks (run in Supabase SQL editor)
- Enqueue and let org_queue_worker pick it up (replace <org-uuid>):
```
insert into public.org_job_queue(org_id, job_type, payload)
values ('<org-uuid>'::uuid, 'ai_assist', '{}'::jsonb);
```
- Observe status transitions with:
```
select id, status, attempts, run_after, error from public.org_job_queue order by id desc limit 20;
```

Notes
- org_queue_worker and synthetic_load require an Authorization header with your SUPABASE_SERVICE_ROLE_KEY in most setups; keep them protected if exposed externally.
- If you want to scope synthetic_load inserts to a specific org, add &org=<org-uuid> to the query string.
- For per‑org concurrency > 1, set an environment variable ORG_WORKER_CONCURRENCY on the org_queue_worker function and/or run multiple instances in parallel.
