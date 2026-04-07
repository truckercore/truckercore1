create or replace view v_access_review as
select 'org_admins' as category, u.id, u.email, m.org_id, m.role, u.last_sign_in_at
from org_members m join auth.users u on u.id = m.user_id
where m.role in ('admin','owner')
union all
select 'scim_tokens', null, t.name, t.org_id, 'scim', t.created_at
from scim_tokens t
union all
select 'api_keys', k.user_id, k.label, k.org_id, 'api_key', k.created_at
from api_keys k;
