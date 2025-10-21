-- docs/supabase/saml_expiry.sql
-- Schedules: cert expiry tracking fields and view. Idempotent and safe to re-run.

alter table public.saml_configs
  add column if not exists idp_cert_expires_at timestamptz,
  add column if not exists next_refresh_at timestamptz;

-- View to flag expiry within 14 days
create or replace view public.v_saml_cert_expiry as
select org_id,
       idp_entity_id,
       idp_cert_pem,
       idp_cert_expires_at,
       (idp_cert_expires_at - now()) as time_to_expiry,
       (idp_cert_expires_at <= now() + interval '14 days') as expiring_soon,
       next_refresh_at
from public.saml_configs
where enabled = true;