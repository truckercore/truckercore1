do $$ begin
  create type tender_status as enum ('draft','open','quoted','awarded','in_transit','delivered','cancelled');
exception when duplicate_object then null; end $$;

alter table tenders
  alter column status type tender_status using status::tender_status;

create table if not exists tender_status_transitions(
  from_status tender_status,
  to_status   tender_status,
  primary key (from_status, to_status)
);

insert into tender_status_transitions(from_status,to_status) values
  ('draft','open'), ('open','quoted'), ('quoted','awarded'),
  ('awarded','in_transit'), ('in_transit','delivered'),
  ('open','cancelled'), ('quoted','cancelled'), ('awarded','cancelled')
on conflict do nothing;

create or replace function enforce_tender_transition()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and NEW.status is distinct from OLD.status then
    if not exists (
      select 1 from tender_status_transitions
      where from_status = OLD.status and to_status = NEW.status
    ) then
      raise exception 'Illegal tender status transition: % -> %', OLD.status, NEW.status;
    end if;
  end if;
  return NEW;
end $$;

drop trigger if exists trg_tender_transition on tenders;
create trigger trg_tender_transition
before update on tenders
for each row execute function enforce_tender_transition();
