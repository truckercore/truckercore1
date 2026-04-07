-- Phase 2: Suggestions feedback + personalized ranking support
-- Tables, indexes, RLS, and RPC to set feedback

-- 1) suggestions_log: record suggestions & user feedback
create table if not exists public.suggestions_log (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  org_id uuid not null,
  context text not null check (context in ('loads','routes')),
  suggestion_json jsonb not null,
  features_snapshot jsonb not null default '{}'::jsonb, -- what we used to rank
  explanation text, -- short human text for UI
  accepted boolean, -- null until user acts
  latency_ms integer,
  ts timestamptz not null default now()
);

create index if not exists suggestions_log_org_user_ts on public.suggestions_log (org_id, user_id, ts desc);
create index if not exists suggestions_log_context on public.suggestions_log (context, ts desc);
create index if not exists suggestions_log_sugg_gin on public.suggestions_log using gin (suggestion_json);

alter table public.suggestions_log enable row level security;

-- RLS: user can read/write own rows within org; admins can read org
create policy if not exists insert_own_suggestions on public.suggestions_log
for insert to authenticated
with check (
  auth.uid() = user_id and public.current_org_id() = org_id
);

create policy if not exists select_suggestions_by_org on public.suggestions_log
for select
using (
  (auth.uid() = user_id and public.current_org_id() = org_id)
  or (public.current_app_role() in ('admin','manager') and public.current_org_id() = org_id)
);

create policy if not exists update_own_suggestions on public.suggestions_log
for update
using (
  auth.uid() = user_id and public.current_org_id() = org_id
) with check (
  auth.uid() = user_id and public.current_org_id() = org_id
);

-- 2) RPC to record feedback quickly from the client
create or replace function public.set_suggestion_feedback(
  p_id bigint,
  p_accepted boolean
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.suggestions_log
  set accepted = p_accepted
  where id = p_id
    and user_id = auth.uid()
    and org_id = public.current_org_id();
end;
$$;

grant execute on function public.set_suggestion_feedback(bigint, boolean) to authenticated;