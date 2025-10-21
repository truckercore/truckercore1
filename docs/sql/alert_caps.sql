create table if not exists alert_caps(
  org_id uuid not null,
  code text not null,
  day date not null default current_date,
  sent int not null default 0,
  cap int not null,
  primary key (org_id, code, day)
);

create or replace function alert_may_send(p_org uuid, p_code text, p_cap int)
returns boolean language plpgsql as $$
declare n int;
begin
  insert into alert_caps(org_id, code, cap) values (p_org, p_code, p_cap)
  on conflict (org_id, code, day) do update set cap = excluded.cap;
  update alert_caps set sent = sent + 1
    where org_id = p_org and code = p_code and day = current_date
    returning sent into n;
  return n <= p_cap;
end $$;
