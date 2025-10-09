begin;

do $$
declare mid uuid; vid uuid;
begin
  select id into mid from ai_models where key='eta';
  if mid is null then
    insert into ai_models(key,owner) values ('eta','ai') returning id into mid;
  end if;

  if not exists (select 1 from ai_model_versions where model_id=mid and status='active') then
    insert into ai_model_versions(model_id,version,artifact_url,status,framework,metrics)
    values (mid, to_char(now(),'YYYYMMDD"T"HH24MISS"Z"'), 'https://example.com/model/eta/v1', 'active','http','{}')
    returning id into vid;

    insert into ai_rollouts(model_id,strategy,active_version_id)
    values (mid,'single',vid)
    on conflict (model_id) do update
      set strategy=excluded.strategy,
          active_version_id=excluded.active_version_id,
          updated_at=now();
  end if;
end$$;
commit;
