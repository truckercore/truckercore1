-- docs/supabase/kyc.sql
-- KYC status helper view. Idempotent and safe to re-run.

-- Assumes a source table public.kyc_verifications(user_id uuid, status text, ...)
-- Produces a simple view v_user_kyc with a boolean kyc_ok flag.

create or replace view public.v_user_kyc as
select user_id,
       (status = 'approved') as kyc_ok
from public.kyc_verifications;

-- Example API usage (TypeScript pseudo):
--
-- async function requireKyc(db, userId: string) {
--   const { data } = await db
--     .from('v_user_kyc')
--     .select('kyc_ok')
--     .eq('user_id', userId)
--     .single()
--   if (!data?.kyc_ok) throw new Error('kyc_required')
-- }
