-- 2025-09-16_hos_routes_scoring.sql
-- Summary:
-- - HOS: Add hos_remaining_drive_minutes RPC using hos_logs (11-hour rule within 14-hour window)
-- - Route rules: add route_rules with avoid_segments and supporting GIN index
-- - Rules loader: include globals ('*') + p_region, ordered by ascending priority
-- - Scoring: add fn_penalty_from_route(route_json)
-- - RLS: ensure validation_audit is org-scoped readable only, with supporting index

set search_path = public;

-- 1) HOS remaining drive minutes (simple approximation: 11h cap in rolling 14h)
create or replace function public.hos_remaining_drive_minutes(
  p_driver_user_id uuid,
  p_at timestamptz default now()
)
returns table(remaining_minutes integer, adjusted_for_hos boolean)
language plpgsql
security definer
stable
as $$
declare
  v_window_start timestamptz := p_at - interval '14 hours';
  v_secs numeric := 0;
  v_minutes int := 0;
begin
  -- Sum overlap of 'driving' segments with the last 14 hours window
  select coalesce(sum(
    greatest(0, extract(epoch from least(h.end_time, p_at) - greatest(h.start_time, v_window_start)))
  ), 0)
  into v_secs
  from public.hos_logs h
  where h.driver_user_id = p_driver_user_id
    and h.status = 'driving'
    and h.end_time > v_window_start
    and h.start_time < p_at;

  v_minutes := greatest(0, (11 * 60) - ceil(v_secs / 60.0)::int);
  -- Heuristic flag: if less than 2 hours remain, downstream should consider HOS adjustments
  return query select v_minutes, (v_minutes < 120);
end;
$$;

revoke all on function public.hos_remaining_drive_minutes(uuid, timestamptz) from public;
grant execute on function public.hos_remaining_drive_minutes(uuid, timestamptz) to authenticated, anon; -- allow RPC reads

-- 2) Route rules with avoid_segments (create if missing)
create table if not exists public.route_rules (
  id uuid primary key default gen_random_uuid(),
  org_id uuid null,
  region text not null default '*', -- e.g., 'CA', 'NJ', or '*'
  priority int not null default 100, -- lower runs first
  active boolean not null default true,
  notes text[] null, -- optional human-facing notes/tags
  avoid_segments text[] not null default '{}'::text[], -- provider segment IDs to avoid
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_route_rules_region_priority on public.route_rules(region, priority asc);
create index if not exists idx_route_rules_avoid_segments_gin on public.route_rules using gin(avoid_segments);

-- 2.1) Rules loader returns globals + regional, ordered by ascending priority
create or replace function public.fn_load_route_rules(p_region text)
returns setof public.route_rules
language sql
stable
as $$
  select *
  from public.route_rules r
  where r.active
    and r.region in ('*', p_region)
  order by r.priority asc, r.created_at asc;
$$;

grant execute on function public.fn_load_route_rules(text) to authenticated, anon;

-- 3) Scoring penalty function based on route notes and HOS flag in meta
create or replace function public.fn_penalty_from_route(p_route jsonb)
returns integer
language plpgsql
stable
as $$
declare
  v_penalty int := 0;
  v_notes jsonb;
  v_note text;
  v_adj boolean := false;
begin
  -- Adjusted for HOS flag can be passed via route.meta.adjusted_for_hos
  v_adj := coalesce((p_route #>> '{meta,adjusted_for_hos}')::boolean, false);
  if v_adj then
    v_penalty := v_penalty + 5;
  end if;

  v_notes := coalesce(p_route->'notes', '[]'::jsonb);
  if jsonb_typeof(v_notes) = 'array' then
    for v_note in select value::text from jsonb_array_elements_text(v_notes) loop
      if v_note ~* '(restricted|truck\s*prohibited|low\s*bridge|hazmat\s*banned|weight\s*limit)' then
        v_penalty := v_penalty + 10;
      elsif v_note ~* '(toll)' then
        v_penalty := v_penalty + 2;
      end if;
    end loop;
  end if;

  return v_penalty;
end;
$$;

grant execute on function public.fn_penalty_from_route(jsonb) to authenticated, anon;

-- 4) Validation audit: ensure table + RLS so rows are visible only by org
create table if not exists public.validation_audit (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  user_id uuid null,
  created_at timestamptz not null default now(),
  payload jsonb null
);

create index if not exists idx_validation_audit_user_time on public.validation_audit(user_id, created_at desc);

alter table public.validation_audit enable row level security;

-- Policy: org-scoped read; writes typically via service role (no insert/update for authenticated)
create policy if not exists validation_audit_read_org on public.validation_audit
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Optional: if you want user-only read tighten with AND user_id=sub
-- Uncomment to restrict further
-- create policy validation_audit_read_user on public.validation_audit
-- for select to authenticated
-- using (
--   org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
--   coalesce(user_id::text, '') = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','')
-- );
