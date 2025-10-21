create or replace function public.accept_tender_quote(p_quote_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tender_id uuid;
begin
  select tender_id into v_tender_id from public.tender_quotes where id = p_quote_id;
  if v_tender_id is null then
    raise exception 'quote not found';
  end if;

  update public.tender_quotes
    set status = 'accepted'
  where id = p_quote_id;

  update public.tenders
    set status = 'awarded'
  where id = v_tender_id;

  update public.tender_quotes
    set status = 'declined'
  where tender_id = v_tender_id and id <> p_quote_id;
end $$;

revoke all on function public.accept_tender_quote(uuid) from public;
grant execute on function public.accept_tender_quote(uuid) to authenticated, service_role;
