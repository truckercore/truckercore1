create table if not exists public.ai_action_plans (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null,
  created_by uuid not null,
  plan jsonb not null,
  signature text not null,
  created_at timestamptz default now()
);

alter table public.ai_action_plans enable row level security;

drop policy if exists ai_actions_rw on public.ai_action_plans;
create policy ai_actions_rw on public.ai_action_plans
  using (org_id = app.current_org_id())
  with check (org_id = app.current_org_id());
