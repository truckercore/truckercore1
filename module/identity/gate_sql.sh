#!/usr/bin/env bash
set -euo pipefail
: "${SUPABASE_DB_URL:?}"
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.saml_configs');" | grep -qi saml_configs
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.scim_users');" | grep -qi scim_users
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.scim_groups');" | grep -qi scim_groups
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.scim_group_members');" | grep -qi scim_group_members
psql "$SUPABASE_DB_URL" -c "select to_regclass('public.identity_audit');" | grep -qi identity_audit
# RLS check on scim tables (expects true)
for t in saml_configs scim_users scim_groups scim_group_members identity_audit; do
  rls=$(psql "$SUPABASE_DB_URL" -At -c "select relrowsecurity from pg_class where oid='public.$t'::regclass;")
  [ "$rls" = "t" ] || { echo "❌ RLS not enabled on $t"; exit 3; }
done
echo "✅ identity SQL gates executed"
