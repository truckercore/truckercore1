# Phase 1 — Saved Searches + Load Alerts (Supabase)

This folder contains SQL and notes to deploy Phase 1 backend components.

## What you get
- Tables: `public.saved_searches`, `public.load_alerts`
- Enums: `app_role_enum`, `match_type_enum`
- Indexes for performance
- RLS policies (owner-only for reads/writes; alerts insert via service role only)
- Optional RPCs: `fn_unseen_alerts_count(uuid)` and `v_exceptions_count(text)` placeholder

## Apply migration
Run in Supabase SQL editor or `supabase db push`:

- File: `docs/supabase/phase1_saved_searches_alerts.sql`

## Edge Function: alerts_check_new_posts
Create a new Edge Function that runs every minute to match new posts to saved searches and create alerts.

1) Create function folder (example path):
```
supabase/functions/alerts_check_new_posts/index.ts
```

2) Minimal pseudocode:
```ts
// supabase/functions/alerts_check_new_posts/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const url = Deno.env.get("SUPABASE_URL")!;
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supa = createClient(url, key);

  const now = new Date();
  const windowMin = 3; // process last 2–3 minutes
  const since = new Date(now.getTime() - windowMin * 60_000).toISOString();

  // 1) Fetch new/updated loads and truck posts since `since`
  // TODO: replace table names as needed
  const { data: loads } = await supa
    .from('loads')
    .select('*')
    .gte('inserted_at', since);

  const { data: searches } = await supa
    .from('saved_searches')
    .select('*')
    .eq('is_active', true);

  // 2) For each search, find matches in loads/truck_posts according to `filters`
  // NOTE: Implement your filter logic (origin/dest radius, equipment, min rate, etc.)

  // 3) Insert into load_alerts with idempotency guard
  // Use a deterministic hash key (user_id + saved_search_id + load_id) to avoid duplicates.

  // 4) Publish realtime event: channel `alerts:{user_id}`
  // Use supabase.realtime channel broadcast if using Realtime server.

  return new Response(JSON.stringify({ ok: true }));
});
```

3) Deploy & schedule cron (every minute):
- Deploy function: `supabase functions deploy alerts_check_new_posts`
- Schedule with Supabase cron or external scheduler to hit the function every minute.

## Realtime channel
- Topic: `alerts:{user_id}`
- Payload minimal fields: `{ alert_id, title, subtitle, cta_deeplink, triggered_at }`

## RLS expectations
- Users can only read their own `saved_searches` and `load_alerts` within their org (JWT claim `app_org_id`).
- Only service role inserts into `load_alerts`.

## Seeds (stage only)
- Add 2 drivers, 1 owner-op, 1 broker, 1 fleet admin
- Create 1–2 saved searches for each
- Seed ~30 loads and ~10 truck posts across 5 states

## Performance targets
- Unseen count via RPC `fn_unseen_alerts_count` for ≤100 ms p95
- Drawer first page ≤ 300 ms p95 with indexes above

## Client wiring in Flutter (already added)
- Alerts bell component: `lib/features/alerts/alerts_drawer.dart`
- Saved search service: `lib/features/alerts/saved_search_service.dart`
- Save Search button on Load Board: `lib/features/loads/loads_list_screen.dart`

Replace placeholders with your real matching logic and seed data as you roll out.
