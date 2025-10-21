# SSO Rollback Runbook

When encountering critical SSO issues during pilot/rollout, use this runbook to safely roll back.

## 1) Toggle SSO off via Entitlements

Disable the SSO feature at the appropriate level (user/org/plan). Prefer org override for targeted rollback.

SQL (org-level override):

```sql
-- Disable SSO for one org
insert into public.org_entitlements(org_id, feature_key, value, reason)
values ('<ORG_ID>', 'sso', 'false'::jsonb, 'rollback')
on conflict (org_id, feature_key) do update set value = 'false'::jsonb, reason = 'rollback';
```

Confirm resolver:

```sql
select * from public.get_entitlement('<ORG_ID>', 'sso', null);
```

## 2) Revoke SCIM token

Rotate or disable the SCIM bearer token for the org.

SQL (example store):

```sql
-- If you store SCIM tokens in public.org_sso_config(scim_token)
update public.org_sso_config set scim_token = null, scim_enabled = false where org_id = '<ORG_ID>';
```

## 3) Rotate OIDC client_secret

In the IdP (Azure AD/Okta/Google), create a new client secret and update your config. If compromised, remove old secret.

```sql
-- Example if stored in DB
update public.org_sso_config set client_secret = null where org_id = '<ORG_ID>';
```

## 4) Revert group→role mappings

Restore to a known-good mapping or fallback minimal role.

```sql
-- Example if mapping stored as JSON
update public.org_sso_config set group_role_map = '{}'::jsonb where org_id = '<ORG_ID>';
```

## 5) Invalidate sessions (optional)

Force sign-out for impacted users to require re-auth after changes.

```sql
-- Supabase example: delete refresh tokens for org
-- adjust to your auth/session store
```

## 6) Communicate status

- Post status update in Slack/Teams
- Notify stakeholders and provide ETA

## 7) Use Admin Bypass if needed

Direct admins to /admin/bypass to activate a 15-minute local bypass while SSO is disabled or being restored. Ensure backend honors and audits bypass for org admins only.

## 8) Verify recovery

- Test SSO with the in-app "Test SSO" self-check
- Monitor `v_sso_error_rate_15m` and `v_scim_failures_15m`

## 9) Re-enable SSO

Once stable, set org entitlement back to true and re-enable SCIM.

```sql
insert into public.org_entitlements(org_id, feature_key, value, reason)
values ('<ORG_ID>', 'sso', 'true'::jsonb, 'restore')
on conflict (org_id, feature_key) do update set value = 'true'::jsonb, reason = 'restore';
```
