# RLS policy catalog

Standard predicates
- Org scope: org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
- Role check: public.has_role('<role>') where roles are: driver, owner_op, broker, fleet_manager
- Ownership: user_id/driver_user_id = jwt.sub when required

Patterns
1) Read within org
```
create policy <table>_read_org on public.<table>
for select to authenticated
using (org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id',''));
```

2) Insert with ownership + role
```
create policy <table>_insert_self on public.<table>
for insert to authenticated
with check (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  user_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'sub','') and
  public.has_role('driver') -- or other role
);
```

3) Update within org (admin roles)
```
create policy <table>_update_admin on public.<table>
for update to authenticated
using (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','') and
  (public.has_role('fleet_manager') or public.has_role('broker'))
)
with check (
  org_id::text = coalesce(current_setting('request.jwt.claims', true)::json->>'app_org_id','')
);
```

Notes
- Service‑managed tables (webhook_subscriptions, webhook_deliveries, event_outbox) are locked down (no direct access) and exposed via SECURITY DEFINER functions when needed.
- All new tables must include org_id and appropriate ownership fields.
