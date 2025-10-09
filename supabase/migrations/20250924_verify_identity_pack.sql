-- 20250924_verify_identity_pack.sql
-- Adds verifier function for identity pack presence, RLS, baseline policies, indexes, and RPC grant checks.
-- Idempotent and safe to re-run.

create or replace function public.verify_identity_pack()
returns jsonb
language plpgsql
security definer
as $$
declare
  -- Expect these tables from your migration:
  v_tables text[] := array[
    'idp_configs','oidc_auth_flow','edge_idempotency',
    'app_sessions','org_settings',
    'scim_users','scim_groups','scim_group_members',
    'role_mappings','sso_events','scim_provision_events',
    'system_audit_events','export_logs'
  ];

  -- For each table we expect at least these policies:
  v_policy_cmds text[] := array['select','insert','update'];

  -- Index expectations (by table -> index names)
  v_index_expectations jsonb := jsonb_build_object(
    'sso_events', jsonb_build_array('sso_events_org_time_idx','idx_sso_events_org_time'),
    'scim_provision_events', jsonb_build_array('scim_events_org_time_idx','idx_scim_ext'),
    'idp_configs', jsonb_build_array('idp_configs_org_idx','idx_idp_org_kind'),
    'app_sessions', jsonb_build_array('app_sessions_org_user_idx','idx_sessions_user_org')
  );

  v_missing_tables text[] := array[]::text[];
  v_missing_rls     text[] := array[]::text[];
  v_missing_policies jsonb := '[]'::jsonb;
  v_missing_indexes  jsonb := '[]'::jsonb;
  v_missing_rpc_grants jsonb := '[]'::jsonb;

  v_tbl text;
  v_has_rls boolean;
  v_cmd text;

  -- RPC expectations
  v_rpc_name regprocedure := 'public.check_export_allowed(text)'::regprocedure;
  v_rpc_grants int := 0;

  -- helpers
  v_idx jsonb;
  v_tbl_indexes text[];
  v_ok boolean := true;
  v_notes jsonb := '[]'::jsonb;

  -- local vars for loops
  v_tbl_key text;
  v_expected_idxs text[];
  v_one text;
  v_missing_list text[];
begin
  ---------------------------------------------------------------------------
  -- A) Tables exist
  ---------------------------------------------------------------------------
  foreach v_tbl in array v_tables loop
    if not exists (
      select 1 from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname='public' and c.relkind in ('r','m') and c.relname = v_tbl
    ) then
      v_missing_tables := v_missing_tables || v_tbl;
    end if;
  end loop;

  ---------------------------------------------------------------------------
  -- B) RLS enabled (only for real tables)
  ---------------------------------------------------------------------------
  foreach v_tbl in array v_tables loop
    select relrowsecurity into v_has_rls
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname=v_tbl and c.relkind='r';

    if v_has_rls is distinct from true then
      v_missing_rls := v_missing_rls || v_tbl;
    end if;
  end loop;

  ---------------------------------------------------------------------------
  -- C) Baseline policies exist (select/insert/update)
  ---------------------------------------------------------------------------
  foreach v_tbl in array v_tables loop
    if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=v_tbl and c.relkind='r') then
      v_missing_list := array[]::text[];
      foreach v_cmd in array v_policy_cmds loop
        if not exists (
          select 1
          from pg_policy p
          join pg_class c on c.oid = p.polrelid
          join pg_namespace n on n.oid = c.relnamespace
          where n.nspname='public' and c.relname=v_tbl and lower(p.polcmd) = v_cmd
        ) then
          v_missing_list := v_missing_list || v_cmd;
        end if;
      end loop;

      if array_length(v_missing_list,1) is not null then
        v_missing_policies := v_missing_policies || jsonb_build_object('table', v_tbl, 'missing', v_missing_list);
      end if;
    end if;
  end loop;

  ---------------------------------------------------------------------------
  -- D) Index presence (by expected index name)
  ---------------------------------------------------------------------------
  for v_tbl_key, v_idx in
    select key, value from jsonb_each(v_index_expectations)
  loop
    select array_agg(i.relname)
    into v_tbl_indexes
    from pg_index x
    join pg_class i on i.oid = x.indexrelid
    join pg_class t on t.oid = x.indrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname='public' and t.relname = v_tbl_key;

    v_expected_idxs := array(
      select jsonb_array_elements_text(v_idx)
    );

    v_missing_list := array[]::text[];
    if v_tbl_indexes is null then
      v_missing_list := v_expected_idxs;
    else
      foreach v_one in array v_expected_idxs loop
        if not (v_one = any(v_tbl_indexes)) then
          v_missing_list := v_missing_list || v_one;
        end if;
      end loop;
    end if;

    if array_length(v_missing_list,1) is not null then
      v_missing_indexes := v_missing_indexes || jsonb_build_object('table', v_tbl_key, 'missing', v_missing_list);
    end if;
  end loop;

  ---------------------------------------------------------------------------
  -- E) RPC grants (check_export_allowed)
  ---------------------------------------------------------------------------
  select count(*) into v_rpc_grants
  from information_schema.role_routine_grants g
  where (specific_schema, specific_name) in (
    select n.nspname, p.proname
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.oid = v_rpc_name
  )
  and grantee in ('authenticated');

  if v_rpc_grants = 0 then
    v_missing_rpc_grants := v_missing_rpc_grants || jsonb_build_object('function','check_export_allowed(text)','missing_grant_for','authenticated');
  end if;

  ---------------------------------------------------------------------------
  -- F) Notes / recommendations
  ---------------------------------------------------------------------------
  if exists (select 1 from pg_proc where proname='check_export_allowed' and prosecdef is true) then
    v_notes := v_notes || jsonb_build_object('advice','Ensure SECURITY DEFINER RPC has minimal privileges and is not granted to anon.');
  end if;

  ---------------------------------------------------------------------------
  -- G) Final result
  ---------------------------------------------------------------------------
  v_ok := (coalesce(array_length(v_missing_tables,1),0)=0)
          and (coalesce(array_length(v_missing_rls,1),0)=0)
          and (jsonb_array_length(v_missing_policies)=0)
          and (jsonb_array_length(v_missing_indexes)=0)
          and (jsonb_array_length(v_missing_rpc_grants)=0);

  return jsonb_build_object(
    'ok', v_ok,
    'missing', jsonb_build_object(
      'tables', coalesce(to_jsonb(v_missing_tables),'[]'::jsonb),
      'rls',    coalesce(to_jsonb(v_missing_rls),'[]'::jsonb),
      'policies', v_missing_policies,
      'indexes',  v_missing_indexes,
      'rpc_grants', v_missing_rpc_grants
    ),
    'notes', v_notes
  );
end
$$;

-- Safe grant: allow authenticated to call the verifier (or restrict to admin if desired)
revoke all on function public.verify_identity_pack() from public;
grant execute on function public.verify_identity_pack() to authenticated;
