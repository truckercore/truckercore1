begin;

-- Store hash of SCIM bearer tokens (not the raw token)
create table if not exists public.scim_tokens (
  org_id uuid primary key,
  token_hash text not null,
  created_at timestamptz not null default now()
);

-- Prevent cross-tenant confusion for SAML IdP configs
create unique index if not exists ux_saml_idp_entity_org
  on public.saml_configs (org_id, idp_entity_id);

commit;
