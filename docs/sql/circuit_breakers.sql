create table if not exists public.circuit_breakers (
  key text primary key,
  tripped boolean not null default false,
  tripped_at timestamptz,
  reason text
);

-- Example usage in functions:
-- if (select tripped from public.circuit_breakers where key='third_party.payments') then
--   -- return cached/fallback response
-- end if;
