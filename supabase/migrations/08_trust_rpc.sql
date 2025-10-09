-- SQL
create or replace function public.apply_trust_delta(p_user_id uuid, p_delta numeric)
returns void language plpgsql security definer as $$
begin
  update public.driver_profiles
  set trust_score = greatest(0, least(1, trust_score + p_delta)),
      updated_at = now()
  where user_id = p_user_id;
end $$;

grant execute on function public.apply_trust_delta(uuid, numeric) to authenticated;
