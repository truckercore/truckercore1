-- docs/sql/circuit_breaker_events.sql
-- Events table for circuit breakers and auto-reset job

create table if not exists public.circuit_breaker_events(
  id bigserial primary key,
  service text not null,
  state text not null check (state in ('open','closed','half_open')),
  flipped_at timestamptz not null default now()
);
create index if not exists idx_cb_events_service_time on public.circuit_breaker_events(service, flipped_at desc);

-- Auto-reset: if a breaker hasn't flipped in >30 minutes, move to half_open then closed
create or replace function public.fn_cb_autoreset()
returns void language plpgsql security definer
set search_path=public
as $$
declare r record;
begin
  for r in
    select service, max(flipped_at) as last_flip
    from public.circuit_breaker_events
    group by service
  loop
    if now() - r.last_flip > interval '30 minutes' then
      insert into public.circuit_breaker_events(service, state) values (r.service, 'half_open');
      -- Health call should be attempted by an external worker; optimistically close after probe window
      insert into public.circuit_breaker_events(service, state) values (r.service, 'closed');
    end if;
  end loop;
end $$;
