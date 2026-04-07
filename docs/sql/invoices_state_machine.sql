do $$ begin
  create type invoice_status as enum ('draft','open','due','paid','void');
exception when duplicate_object then null; end $$;

alter table invoices
  alter column status type invoice_status using status::invoice_status;

create table if not exists invoice_status_transitions(
  from_status invoice_status,
  to_status   invoice_status,
  primary key (from_status, to_status)
);

insert into invoice_status_transitions(from_status,to_status) values
  ('draft','open'), ('open','due'), ('open','void'),
  ('due','paid'), ('due','void')
on conflict do nothing;

create or replace function enforce_invoice_transition()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and NEW.status is distinct from OLD.status then
    if not exists (
      select 1 from invoice_status_transitions
      where from_status = OLD.status and to_status = NEW.status
    ) then
      raise exception 'Illegal invoice status transition: % -> %', OLD.status, NEW.status;
    end if;
  end if;
  return NEW;
end $$;

drop trigger if exists trg_invoice_transition on invoices;
create trigger trg_invoice_transition
before update on invoices
for each row execute function enforce_invoice_transition();
