-- Always pin search_path at entry, never rely on caller default
create or replace function app.safe_upsert_load(_id uuid, _org uuid, _data jsonb)
returns void
language plpgsql
security definer
as $$
begin
  perform set_config('search_path', 'public,extensions', true);

  -- RLS-aware: prefer policies; if bypassing, document justification
  update public.loads set data=_data where id=_id and org_id=_org;
  if not found then
    insert into public.loads(id, org_id, data) values (_id, _org, _data);
  end if;
end $$;
