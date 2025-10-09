begin;
-- Ensure uniqueness of SP entity per org to avoid cross-tenant ACS confusion
create unique index if not exists uq_saml_sp_entity_per_org on public.saml_configs (org_id, sp_entity_id);
commit;
