-- Migration: Cache, invalidation, and rate limiting
-- Date: 2025-09-27

-- Cache for merged_profile keyed by (org_id, user_id)
create table if not exists public.cached_merged_profile (
  org_id uuid not null,
  user_id uuid not null,
  cached_at timestamptz not null default now(),
  ttl_seconds int not null default 600,
  payload jsonb not null,
  primary key (org_id, user_id)
);

create or replace function public.get_merged_profile(p_org uuid, p_user uuid)
returns jsonb language plpgsql as $$
declare res jsonb; fresh boolean;
begin
  select (now()-cached_at) < make_interval(secs => ttl_seconds), payload
  into fresh, res
  from public.cached_merged_profile
  where org_id = p_org and user_id = p_user;

  if res is null or not fresh then
    -- recompute on miss from learned_profiles_features (latest)
    select jsonb_build_object(
             'features', coalesce((select features from public.learned_profiles_features
                                   where org_id=p_org and user_id=p_user
                                   order by feature_date desc limit 1), '{}'::jsonb)
           ) into res;
    insert into public.cached_merged_profile(org_id, user_id, payload, cached_at)
    values (p_org, p_user, res, now())
    on conflict (org_id, user_id) do update
    set payload = excluded.payload, cached_at = now();
  end if;
  return res;
end $$;

-- Invalidate on feedback events (insert/update)
create or replace function public.invalidate_cache_on_feedback()
returns trigger language plpgsql as $$
begin
  delete from public.cached_merged_profile
  where org_id = new.org_id and user_id = new.user_id;
  return new;
end $$;

drop trigger if exists trg_invalidate_cache_on_feedback on public.suggestions_log;
create trigger trg_invalidate_cache_on_feedback
after insert or update on public.suggestions_log
for each row execute function public.invalidate_cache_on_feedback();

-- Simple token-bucket-ish rate limiting (per scope+key)
create table if not exists public.rate_limit_counters (
  scope text not null,
  key text not null,
  window_start timestamptz not null,
  count int not null,
  limit int not null,
  primary key (scope, key, window_start)
);

create or replace function public.check_rate_limit(p_scope text, p_key text, p_limit int, p_window_secs int)
returns boolean language plpgsql as $$
declare wstart timestamptz := date_trunc('second', now() - make_interval(secs => p_window_secs));
begin
  insert into public.rate_limit_counters(scope, key, window_start, count, limit)
  values (p_scope, p_key, wstart, 1, p_limit)
  on conflict (scope, key, window_start) do update set count = public.rate_limit_counters.count + 1;

  return (select count <= limit from public.rate_limit_counters where scope=p_scope and key=p_key and window_start=wstart);
end $$;
