create or replace function mark_open_invoices_due(p_days int default 7)
returns int language plpgsql security definer set search_path=public as $$
declare c int;
begin
  update invoices
    set status='due', due_at = now()
  where status='open'
    and created_at < now() - make_interval(days => p_days);
  GET DIAGNOSTICS c = ROW_COUNT;
  return c;
end $$;
