-- Migration: learned_profiles_features daily computation
-- Date: 2025-09-27

create table if not exists public.learned_profiles_features (
  org_id uuid not null,
  user_id uuid not null,
  feature_date date not null,
  features jsonb not null,
  primary key (org_id, user_id, feature_date)
);

create or replace function public.compute_org_profile_features(p_org_id uuid)
returns void language plpgsql as $$
begin
  insert into public.learned_profiles_features (org_id, user_id, feature_date, features)
  select p_org_id,
         user_id,
         (now() - interval '1 day')::date as feature_date,
         jsonb_build_object(
           'events_last7', (select count(*) from public.behavior_events be
                             where be.org_id = p_org_id and be.user_id = sl.user_id
                               and be.occurred_at >= now() - interval '7 days'),
           'ctr_last7',    (select avg(case when accepted then 1 else 0 end)::numeric
                             from public.suggestions_log s2
                             where s2.org_id = p_org_id and s2.user_id = sl.user_id
                               and s2.updated_at >= now() - interval '7 days')
         )
  from public.suggestions_log sl
  where sl.org_id = p_org_id
  group by sl.user_id
  on conflict (org_id, user_id, feature_date) do update
  set features = excluded.features;
end$$;
