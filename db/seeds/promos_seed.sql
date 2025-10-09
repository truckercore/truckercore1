insert into orgs (id,name,kind) values ('00000000-0000-0000-0000-000000000010','Demo Stop','truckstop')
on conflict do nothing;

insert into promotions (id, org_id, title, description, type, value_cents, location_ids, start_at, end_at, rules)
values ('00000000-0000-0000-0000-00000000PRMO','00000000-0000-0000-0000-000000000010',
        'Coffee -$1', 'Any size coffee $1 off', 'amount', 100, '{}',
        now() - interval '1 day', now() + interval '7 days', '{"per_user_limit": 1}')
on conflict do nothing;
