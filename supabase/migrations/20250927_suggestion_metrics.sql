-- Migration: suggestion metrics daily and refresh function
-- Date: 2025-09-27

create table if not exists public.suggestion_metrics_daily (
  org_id uuid not null,
  bucket_date date not null,
  context text not null,
  suggestion_type text not null,
  shown_cnt bigint not null,
  accepted_cnt bigint not null,
  ctr numeric not null,
  primary key (org_id, bucket_date, context, suggestion_type)
);

create or replace function public.refresh_suggestion_metrics()
returns void language plpgsql as $$
begin
  insert into public.suggestion_metrics_daily (org_id, bucket_date, context, suggestion_type, shown_cnt, accepted_cnt, ctr)
  select org_id,
         updated_at::date,
         coalesce(context, 'default') as context,
         coalesce(suggestion_type, 'default') as suggestion_type,
         count(*) as shown_cnt,
         sum(case when accepted then 1 else 0 end) as accepted_cnt,
         case when count(*)=0 then 0 else sum(case when accepted then 1 else 0 end)::numeric / count(*) end as ctr
  from public.suggestions_log
  where updated_at >= now() - interval '2 days'
  group by 1,2,3,4
  on conflict (org_id, bucket_date, context, suggestion_type)
  do update set shown_cnt = excluded.shown_cnt,
                accepted_cnt = excluded.accepted_cnt,
                ctr = excluded.ctr;
end$$;
