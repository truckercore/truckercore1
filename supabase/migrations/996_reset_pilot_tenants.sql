create or replace function public.reset_pilot_tenants()
returns void language plpgsql security definer set search_path=public as $$
begin
  -- Clear transient pilot data (keep schema & users)
  delete from public.alert_outbox where created_at < now() - interval '7 days';
  delete from public.community_votes where true;
  delete from public.community_posts where created_at < now() - interval '30 days';
  -- Re-run rollups for both pilot orgs
  perform public.rollup_org_metrics_daily_chunked(200);
end; $$;