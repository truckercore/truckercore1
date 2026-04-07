create table if not exists admin_action_limits(
  org_id uuid,
  action text,
  tokens int not null default 3,
  refreshed_at timestamptz not null default now(),
  primary key (org_id, action)
);

create or replace function admin_take_token(p_org uuid, p_action text, p_capacity int default 3, p_refill int default 3)
returns table(allowed boolean, next_allowed_at timestamptz)
language plpgsql as $$
declare nowts timestamptz := now(); t int;
begin
  insert into admin_action_limits(org_id, action, tokens, refreshed_at)
  values (p_org, p_action, p_capacity-1, nowts)
  on conflict (org_id, action) do update set
    tokens = greatest(0, least(p_capacity,
      admin_action_limits.tokens + floor(extract(epoch from (nowts - admin_action_limits.refreshed_at))/60.0)*p_refill) - 1),
    refreshed_at = nowts
  returning tokens into t;

  return query select (t >= 0) as allowed,
    case when t >= 0 then nowts else admin_action_limits.refreshed_at + interval '1 minute' end as next_allowed_at
    from admin_action_limits where org_id=p_org and action=p_action;
end $$;
