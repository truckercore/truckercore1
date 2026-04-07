begin;

-- Link ground truth and compute absolute error for ETA; aggregate a simple MAE metric
create or replace function public.fn_ai_closeout_eta(
  p_subject_id text,
  p_arrived_unix bigint,
  p_org_id uuid default null,
  p_model_version text default null
) returns void
language plpgsql
security definer
as $$
begin
  update public.ai_predictions
  set actual = jsonb_build_object('arrived_unix', p_arrived_unix),
      error = case when (prediction ? 'eta_unix')
              then jsonb_build_object('abs_sec', abs((prediction->>'eta_unix')::bigint - p_arrived_unix))
              else null end
  where module = 'eta'
    and subject_id = p_subject_id
    and (p_org_id is null or org_id = p_org_id)
    and (p_model_version is null or model_version = p_model_version);

  -- Aggregate MAE for this subject/version (example; caller can do broader windows in jobs)
  insert into public.ai_metrics (org_id, module, metric, value, model_version, dims)
  select org_id, 'eta', 'mae_sec', avg((error->>'abs_sec')::numeric), model_version, jsonb_build_object('subject','eta')
  from public.ai_predictions
  where module='eta' and subject_id = p_subject_id and actual is not null and error ? 'abs_sec'
  group by org_id, model_version
  on conflict do nothing;
end;
$$;

grant execute on function public.fn_ai_closeout_eta(text,bigint,uuid,text) to service_role;

commit;
