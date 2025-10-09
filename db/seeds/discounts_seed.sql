insert into orgs (id,name,kind) values ('00000000-0000-0000-0000-0000000000F1','Demo Fleet','fleet')
on conflict do nothing;

insert into fleet_discounts (id, fleet_org_id, stop_org_id, fuel_cents, def_cents, start_at, end_at)
values ('00000000-0000-0000-0000-00000000DISC','00000000-0000-0000-0000-0000000000F1',
        '00000000-0000-0000-0000-000000000010', 10, 5, now()-interval '1d', now()+interval '30d')
on conflict do nothing;
