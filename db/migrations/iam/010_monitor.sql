begin;

alter table if exists saml_idp_configs
  add column if not exists cert_expires_at timestamptz;

create or replace view iam_saml_expiring as
select org_id, entity_id, cert_expires_at,
       (cert_expires_at - now()) as time_remaining
from saml_idp_configs
where cert_expires_at is not null
  and cert_expires_at < now() + interval '30 days';

create or replace view iam_group_drift as
select ou.org_id, ou.user_id, ou.role
from org_users ou
left join scim_external_ids se on se.org_id = ou.org_id and se.object_type='user' and se.internal_id = ou.user_id
where se.external_id is null and ou.role <> 'suspended';

grant select on iam_saml_expiring, iam_group_drift to service_role, authenticated;

commit;
