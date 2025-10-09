begin;

-- Drift/accuracy finish guard (placeholder implementation)
-- Returns true if current model health is within provided thresholds (MAE delta and PSI)
-- TODO: Replace with real computations from rollup views/metrics once available
create or replace function public.fn_ai_finish_guard(
  p_model_key text,
  p_max_mae_delta numeric,
  p_max_psi numeric
) returns boolean
language plpgsql
security definer
as $$
declare
  v_mae_delta numeric := 0;
  v_psi numeric := 0;
begin
  -- Placeholder: in production, compute from ai_accuracy_rollups and ai_drift_snapshots
  if v_mae_delta > p_max_mae_delta then return false; end if;
  if v_psi > p_max_psi then return false; end if;
  return true;
end $$;

revoke all on function public.fn_ai_finish_guard(text,numeric,numeric) from public;
grant execute on function public.fn_ai_finish_guard(text,numeric,numeric) to service_role;

commit;
