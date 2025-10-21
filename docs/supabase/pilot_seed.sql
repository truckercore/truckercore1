-- docs/supabase/pilot_seed.sql
-- Pilot-in-a-box seeding RPC. Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- Ensure features table exists (from entitlements package); otherwise this will be a no-op insert
insert into public.features(key, description)
values ('exec_analytics','Executive analytics bundle')
on conflict (key) do nothing;

create or replace function public.fn_pilot_seed(p_org_id uuid, p_template text default 'truck_stop')
returns jsonb
language plpgsql
security definer
as $$
begin
  -- Enable exec_analytics at the org level as a pilot override
  insert into public.org_entitlements(org_id, feature_key, value, reason)
  values (p_org_id, 'exec_analytics', 'true'::jsonb, 'pilot')
  on conflict (org_id, feature_key) do update set value='true'::jsonb, reason='pilot', expires_at = null;

  -- Optionally seed a pilot banner flag via org_pilot_flags if available
  begin
    insert into public.org_pilot_flags(org_id, pilot_mode, started_at, updated_at)
    values (p_org_id, true, now(), now())
    on conflict (org_id) do update set pilot_mode = true, updated_at = now();
  exception when undefined_table then
    -- ignore if org_pilot_flags not installed
    null;
  end;

  -- TODO: Seed sample promos/POIs based on p_template; left as domain-specific implementation.

  return jsonb_build_object('status','ok','org_id',p_org_id,'template',p_template);
end $$;

grant execute on function public.fn_pilot_seed(uuid,text) to service_role, authenticated;
