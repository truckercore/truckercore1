-- Adds updated_at column to entitlements and a trigger to maintain it

alter table if exists public.entitlements
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Ensure only one trigger exists
drop trigger if exists tr_set_updated_at on public.entitlements;
create trigger tr_set_updated_at
before update on public.entitlements
for each row execute function public.tg_set_updated_at();
