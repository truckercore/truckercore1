begin;

-- Evidence log on entitlement changes (insert/update)
create or replace function public.trg_log_entitlement_change()
returns trigger
language plpgsql
as $$
begin
  insert into public.compliance_evidence(org_id, artifact, hash_sha256, source, created_at)
  values (coalesce(new.org_id, old.org_id),
          concat('entitlement:', coalesce(new.feature_key, old.feature_key), ':', coalesce(new.enabled, old.enabled)),
          null,
          'entitlement_change',
          now());
  return new;
end;
$$;

drop trigger if exists trg_entitlement_evidence on public.entitlements;
create trigger trg_entitlement_evidence
after insert or update on public.entitlements
for each row execute function public.trg_log_entitlement_change();

commit;
