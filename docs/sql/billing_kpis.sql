-- Exec KPIs for billing/AI adoption & webhook health
create or replace view public.v_billing_kpis as
select
  (select count(*) from public.billing_profiles where coalesce(ai_enabled,false)) as ai_accounts,
  (select count(*) from public.billing_profiles where tier = 'premium') as premium_accounts,
  (select count(*) from public.stripe_events_dedup where received_at > now() - interval '24 hours') as webhooks_24h,
  (select count(*) from public.billing_profiles where updated_at > now() - interval '24 hours' and coalesce(ai_enabled,false)) as ai_activations_24h;
