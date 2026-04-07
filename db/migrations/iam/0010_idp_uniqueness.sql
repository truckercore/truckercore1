begin;
create unique index if not exists uniq_idp_per_org on public.saml_configs (org_id);
create unique index if not exists uniq_idp_entity_audience on public.saml_configs (org_id, idp_entity_id, sp_entity_id);
commit;
