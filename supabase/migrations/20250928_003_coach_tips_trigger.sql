-- coach-safety trigger and table
-- Requires pg_net (aka http) extension for net.http_post
create extension if not exists pg_net;

create table if not exists public.coach_tips (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null,
  org_id uuid,
  tip text not null,
  created_at timestamptz not null default now()
);

-- RLS optional: readable by authenticated within org (mirror safety_alerts policy if desired)
alter table public.coach_tips enable row level security;

drop policy if exists "coach tips tenant read" on public.coach_tips;
create policy "coach tips tenant read" on public.coach_tips
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));

-- Helper trigger function to notify Edge Function via HTTP
create or replace function public.notify_coach_safety()
returns trigger
language plpgsql
security definer
as $$
begin
  perform net.http_post(
    url := current_setting('app.edge_coach_safety_url', true),
    content := jsonb_build_object('type','INSERT','record', to_jsonb(NEW)),
    headers := jsonb_build_object('content-type','application/json')
  );
  return NEW;
end;
$$;

-- Trigger on safety_alerts insert
drop trigger if exists trg_coach_safety on public.safety_alerts;
create trigger trg_coach_safety
after insert on public.safety_alerts
for each row execute function public.notify_coach_safety();

-- Note: set the runtime parameter app.edge_coach_safety_url to your deployed function URL, e.g.:
-- select set_config('app.edge_coach_safety_url', 'https://<project>.functions.supabase.co/coach-safety', true);
