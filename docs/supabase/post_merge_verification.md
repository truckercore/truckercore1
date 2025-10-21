Post‑merge verification checklist (10 mins)

Env & wiring
- SUPABASE_URL matches your project REST URL and has no trailing slash (e.g., https://<ref>.supabase.co).
- Launch Flutter with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON=...
- App boot health ping succeeds: select now from health_ping_view returns 200 and does not hit CORS errors.

Auth & RLS
- Login as a user whose JWT includes app_org_id (in app_metadata or custom claim).
- select * from escalation_logs returns only rows for your org.
- Insert into escalation_logs succeeds only when org_id == JWT app_org_id.

RLS spot checks (psql):
- RLS enabled?
  select relname, relrowsecurity from pg_class where relname in ('escalation_logs','alerts','retests','remediations');
- Expect rows only for caller’s org
  set local role authenticated; select * from public.escalation_logs limit 3;
- Should FAIL: insert with mismatched org_id
  insert into public.escalation_logs (id, alert_id, org_id, title, status)
  values (gen_random_uuid(), (select id from public.alerts limit 1), gen_random_uuid(), 'Bad insert', 'open');

UI/UX
- EscalationLogCard: first page loads; scroll near end shows spinner and fetches next page.
- Empty states: zero rows shows illustration + “system is healthy 🎉”.
- Cross‑linking: tap a row → opens /alerts/:id and fields render on detail page.
- Theming: dark mode — cards inherit ColorScheme; overrides optional.
- RetestStatusCard & RemediationEffectivenessCard: render rows; with no data, show friendly tips.

Quality/observability
- TC.guard logs OK:/ERR: with op names to console.
- Slow networks: pagination remains responsive; list stays scrollable with spinner placeholder.

Seeds (idempotent)
Run once to bootstrap demo data:
  \i docs/seeds/escalations_seed.sql

The seed file creates alerts, escalation_logs (with org_id), a scheduled retest, and a remediation.

Health ping view
DB migration adds:
  create or replace view public.health_ping_view as select now() as now;
  revoke all on public.health_ping_view from public;
  grant select on public.health_ping_view to anon, authenticated;

Flutter health probe reads health_ping_view (see lib/core/supabase/backend_banner.dart). A tiny smoke widget is available:
  import 'package:truckercore1/core/supabase/smoke.dart';
  // Drop somewhere in your dashboard
  const SupabaseSmoke();

Run
- Web server device (works without auto‑launching a browser):
  flutter run -d web-server --web-port 52848 --web-hostname localhost --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON=...
- Chrome explicit (if needed): see scripts/web_server_launch.md or make run-flutter-chrome.

Rollback
- The migration is idempotent. To remove seeds only:
  delete from public.escalation_logs where title = 'Initial escalation';
  delete from public.remediations where fix_title = 'Firmware patch 1.2.3';
