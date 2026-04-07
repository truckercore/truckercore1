begin;

-- Extend ai_promo_audit with optional fields if they don't exist yet
alter table if exists public.ai_promo_audit
  add column if not exists org_id uuid,
  add column if not exists before jsonb,
  add column if not exists after jsonb;

commit;
