begin;

-- Composite index (org + email) for fast lookups
create index if not exists idx_driver_invites_org_email
  on driver_invites (org_id, lower(email));

-- Accept RPC ensures accepted_at set
create or replace function accept_driver_invite(p_token text)
returns uuid
language plpgsql
security definer
as $$
declare v_id uuid; v_user uuid;
begin
  select id, user_id into v_id, v_user from driver_invites where token = p_token and accepted_at is null;
  if v_id is null then
    raise exception 'invalid_or_used_token';
  end if;
  update driver_invites set accepted_at = now() where id = v_id;
  return v_id;
end;
$$;
grant execute on function accept_driver_invite(text) to authenticated, service_role;

commit;
