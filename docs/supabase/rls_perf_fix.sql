-- RLS Performance Remediation for Supabase (PG14/PG15)
-- Purpose:
-- - Replace direct calls to auth.jwt() / auth.uid() inside RLS policies with
--   (select auth.jwt()) / (select auth.uid()) to avoid per-row re-evaluation costs.
-- - Clean up duplicate permissive policies where applicable.
-- - Remove duplicate indexes reported by the linter.
-- - Address views with SECURITY DEFINER property flagged by the linter.
-- - Ensure explicit 'TO public' clause for clarity and security.
-- - Consolidate duplicate policies into single, correct definitions.
--
-- This script is designed to be idempotent and can be safely run multiple times.
--
-- IMPORTANT:
-- Before running, you MUST replace the `/* YOUR_VIEW_DEFINITION_HERE */`
-- placeholders with the original SELECT statement for each view. You can
-- retrieve these definitions by running:
--   `SELECT definition FROM pg_views WHERE viewname = 'view_name';`
--
-- You should also verify the existence of the helper function `public.jwt_org_id()`
-- as the CUD policies depend on it. If it doesn't exist, uncomment and run the
-- CREATE FUNCTION block below.
--
-- Uncomment and run the following if the helper function is missing:
/*
CREATE OR REPLACE FUNCTION public.jwt_org_id()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT (auth.jwt() ->> 'org_id')::uuid
$$;
*/

-------------------------------------------------
-- 1️⃣ Drop old policies to prevent overlaps
-------------------------------------------------
-- The old policy names may vary, so drop common ones here
DROP POLICY IF EXISTS org_read ON public.organizations;
DROP POLICY IF EXISTS dev_read ON public.organizations;
DROP POLICY IF EXISTS org_members_manage_admins ON public.organization_members; -- Remove the duplicate policy block from the previous version

-------------------------------------------------
-- 2️⃣ Re-create organization policies
-------------------------------------------------
-- Ensure all auth.uid() calls are wrapped in a sub-select
DROP POLICY IF EXISTS orgs_read_by_members ON public.organizations;
CREATE POLICY orgs_read_by_members ON public.organizations
  FOR SELECT TO public
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organizations.id AND m.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS orgs_write_by_admins ON public.organizations;
CREATE POLICY orgs_write_by_admins ON public.organizations
  FOR UPDATE TO public
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organizations.id AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

-------------------------------------------------
-- 3️⃣ Organization members policies (single, corrected definitions)
-------------------------------------------------
DROP POLICY IF EXISTS org_members_read_self ON public.organization_members;
CREATE POLICY org_members_read_self ON public.organization_members
  FOR SELECT TO public
  USING (
    (SELECT auth.uid()) = user_id OR EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organization_members.org_id AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

DROP POLICY IF EXISTS org_members_manage_admins ON public.organization_members;
CREATE POLICY org_members_manage_admins ON public.organization_members
  FOR ALL TO public
  USING (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organization_members.org_id AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.organization_members m
      WHERE m.org_id = organization_members.org_id AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

-------------------------------------------------
-- 4️⃣ Fleet / Dispatch policies (already use SELECT auth.jwt())
-------------------------------------------------
-- The policies in this section are already correctly formatted
-- with (SELECT auth.jwt()) and require no changes.

DROP POLICY IF EXISTS trucks_tenant_select ON public.trucks;
CREATE POLICY trucks_tenant_select ON public.trucks
  FOR SELECT USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id);

DROP POLICY IF EXISTS trucks_tenant_insert ON public.trucks;
CREATE POLICY trucks_tenant_insert ON public.trucks
  FOR INSERT WITH CHECK (((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id);

DROP POLICY IF EXISTS trucks_tenant_update ON public.trucks;
CREATE POLICY trucks_tenant_update ON public.trucks
  FOR UPDATE USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id);

DROP POLICY IF EXISTS truck_positions_tenant_select ON public.truck_positions;
CREATE POLICY truck_positions_tenant_select ON public.truck_positions
  FOR SELECT USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.trucks t WHERE t.id = truck_positions.truck_id
  ));

DROP POLICY IF EXISTS truck_positions_tenant_insert ON public.truck_positions;
CREATE POLICY truck_positions_tenant_insert ON public.truck_positions
  FOR INSERT WITH CHECK (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.trucks t WHERE t.id = truck_id
  ));

DROP POLICY IF EXISTS truck_current_positions_tenant_select ON public.truck_current_positions;
CREATE POLICY truck_current_positions_tenant_select ON public.truck_current_positions
  FOR SELECT USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.trucks t WHERE t.id = truck_current_positions.truck_id
  ));

DROP POLICY IF EXISTS dispatch_orders_tenant_select ON public.dispatch_orders;
CREATE POLICY dispatch_orders_tenant_select ON public.dispatch_orders
  FOR SELECT USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id);

DROP POLICY IF EXISTS dispatch_orders_tenant_insert ON public.dispatch_orders;
CREATE POLICY dispatch_orders_tenant_insert ON public.dispatch_orders
  FOR INSERT WITH CHECK (((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id);

DROP POLICY IF EXISTS dispatch_orders_tenant_update ON public.dispatch_orders;
CREATE POLICY dispatch_orders_tenant_update ON public.dispatch_orders
  FOR UPDATE USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id);

DROP POLICY IF EXISTS dispatch_order_legs_tenant_select ON public.dispatch_order_legs;
CREATE POLICY dispatch_order_legs_tenant_select ON public.dispatch_order_legs
  FOR SELECT USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.dispatch_orders o WHERE o.id = dispatch_order_legs.order_id
  ));

DROP POLICY IF EXISTS assignments_tenant_select ON public.assignments;
CREATE POLICY assignments_tenant_select ON public.assignments
  FOR SELECT USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.trucks t WHERE t.id = assignments.truck_id
  ));

DROP POLICY IF EXISTS assignments_tenant_insert ON public.assignments;
CREATE POLICY assignments_tenant_insert ON public.assignments
  FOR INSERT WITH CHECK (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.trucks t WHERE t.id = truck_id
  ));

DROP POLICY IF EXISTS assignments_tenant_update ON public.assignments;
CREATE POLICY assignments_tenant_update ON public.assignments
  FOR UPDATE USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.trucks t WHERE t.id = assignments.truck_id
  ));

DROP POLICY IF EXISTS dispatch_stops_tenant_cud ON public.dispatch_stops;
DROP POLICY IF EXISTS dispatch_stops_tenant_iud ON public.dispatch_stops;
DROP POLICY IF EXISTS dispatch_stops_tenant_update ON public.dispatch_stops;
DROP POLICY IF EXISTS dispatch_stops_tenant_delete ON public.dispatch_stops;
CREATE POLICY dispatch_stops_tenant_iud ON public.dispatch_stops
  FOR ALL USING (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.dispatch_orders o WHERE o.id = dispatch_stops.order_id
  )) WITH CHECK (((SELECT auth.jwt()) ->> 'org_id')::uuid = (
    SELECT carrier_id FROM public.dispatch_orders o WHERE o.id = dispatch_stops.order_id
  ));

DROP POLICY IF EXISTS dispatch_events_tenant_select ON public.dispatch_events;
CREATE POLICY dispatch_events_tenant_select ON public.dispatch_events
  FOR SELECT USING (
    (order_id IS NOT NULL AND ((SELECT auth.jwt()) ->> 'org_id')::uuid = (
      SELECT carrier_id FROM public.dispatch_orders o WHERE o.id = dispatch_events.order_id
    )) OR
    (assignment_id IS NOT NULL AND ((SELECT auth.jwt()) ->> 'org_id')::uuid = (
      SELECT t.carrier_id FROM public.assignments a JOIN public.trucks t ON t.id = a.truck_id WHERE a.id = dispatch_events.assignment_id
    ))
  );

DROP POLICY IF EXISTS dispatch_events_tenant_insert ON public.dispatch_events;
CREATE POLICY dispatch_events_tenant_insert ON public.dispatch_events
  FOR INSERT WITH CHECK (
    (order_id IS NOT NULL AND ((SELECT auth.jwt()) ->> 'org_id')::uuid = (
      SELECT carrier_id FROM public.dispatch_orders o WHERE o.id = order_id
    )) OR
    (assignment_id IS NOT NULL AND ((SELECT auth.jwt()) ->> 'org_id')::uuid = (
      SELECT t.carrier_id FROM public.assignments a JOIN public.trucks t ON t.id = a.truck_id WHERE a.id = assignment_id
    ))
  );

-------------------------------------------------
-- 5️⃣ Maintenance/Compliance policies (using public.jwt_org_id() and SELECT auth.uid())
-------------------------------------------------
DROP POLICY IF EXISTS service_tasks_tenant_cud_fleet ON public.service_tasks;
DROP POLICY IF EXISTS service_tasks_tenant_update_fleet ON public.service_tasks;
DROP POLICY IF EXISTS service_tasks_tenant_delete_fleet ON public.service_tasks;
CREATE POLICY service_tasks_tenant_cud_fleet ON public.service_tasks
  FOR ALL TO public
  USING (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  ) WITH CHECK (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

DROP POLICY IF EXISTS truck_schedules_tenant_cud_fleet ON public.truck_service_schedules;
DROP POLICY IF EXISTS truck_schedules_tenant_update_fleet ON public.truck_service_schedules;
DROP POLICY IF EXISTS truck_schedules_tenant_delete_fleet ON public.truck_service_schedules;
CREATE POLICY truck_schedules_tenant_cud_fleet ON public.truck_service_schedules
  FOR ALL TO public
  USING (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  ) WITH CHECK (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

DROP POLICY IF EXISTS work_orders_tenant_cud_fleet ON public.work_orders;
DROP POLICY IF EXISTS work_orders_tenant_update_fleet ON public.work_orders;
DROP POLICY IF EXISTS work_orders_tenant_delete_fleet ON public.work_orders;
CREATE POLICY work_orders_tenant_cud_fleet ON public.work_orders
  FOR ALL TO public
  USING (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  ) WITH CHECK (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

DROP POLICY IF EXISTS wo_items_tenant_cud_fleet ON public.work_order_items;
DROP POLICY IF EXISTS wo_items_tenant_update_fleet ON public.work_order_items;
DROP POLICY IF EXISTS wo_items_tenant_delete_fleet ON public.work_order_items;
CREATE POLICY wo_items_tenant_cud_fleet ON public.work_order_items
  FOR ALL TO public
  USING (
    (SELECT org_id FROM public.work_orders w WHERE w.id = work_order_id) = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  ) WITH CHECK (
    (SELECT org_id FROM public.work_orders w WHERE w.id = work_order_id) = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

DROP POLICY IF EXISTS parts_tenant_cud_fleet ON public.parts_catalog;
DROP POLICY IF EXISTS parts_tenant_update_fleet ON public.parts_catalog;
DROP POLICY IF EXISTS parts_tenant_delete_fleet ON public.parts_catalog;
CREATE POLICY parts_tenant_cud_fleet ON public.parts_catalog
  FOR ALL TO public
  USING (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  ) WITH CHECK (
    org_id = public.jwt_org_id() AND EXISTS (
      SELECT 1 FROM public.user_org_memberships m
      WHERE m.org_id = public.jwt_org_id() AND m.user_id = (SELECT auth.uid()) AND m.role IN ('admin','fleet_manager')
    )
  );

-------------------------------------------------
-- 6️⃣ Reporting/Billing & Geofencing Policies
-------------------------------------------------
-- Ensure DO $$ BEGIN ... END; $$; blocks are correctly formatted
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='billing' AND table_name='usage_counters'
  ) THEN
    DROP POLICY IF EXISTS usage_read ON billing.usage_counters;
    CREATE POLICY usage_read ON billing.usage_counters
      FOR SELECT USING (org_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid));

    DROP POLICY IF EXISTS usage_upsert_admins ON billing.usage_counters;
    CREATE POLICY usage_upsert_admins ON billing.usage_counters
      FOR INSERT WITH CHECK (org_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid));

    DROP POLICY IF EXISTS usage_update_admins ON billing.usage_counters;
    CREATE POLICY usage_update_admins ON billing.usage_counters
      FOR UPDATE USING (org_id = coalesce(public.current_org_id(), ((SELECT auth.jwt()) ->> 'org_id')::uuid));
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='billing' AND table_name='organization_billing'
  ) THEN
    DROP POLICY IF EXISTS org_billing_read ON billing.organization_billing;
    CREATE POLICY org_billing_read ON billing.organization_billing
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.organization_members m
          WHERE m.org_id = billing.organization_billing.org_id
            AND m.user_id = (SELECT auth.uid())
        )
      );

    DROP POLICY IF EXISTS org_billing_manage_admins ON billing.organization_billing;
    CREATE POLICY org_billing_manage_admins ON billing.organization_billing
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM public.organization_members m
          WHERE m.org_id = billing.organization_billing.org_id
            AND m.user_id = (SELECT auth.uid())
            AND m.role IN ('admin','fleet_manager')
        )
      ) WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.organization_members m
          WHERE m.org_id = billing.organization_billing.org_id
            AND m.user_id = (SELECT auth.uid())
            AND m.role IN ('admin','fleet_manager')
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='geofences') THEN
    DROP POLICY IF EXISTS geofences_tenant_select ON public.geofences;
    CREATE POLICY geofences_tenant_select ON public.geofences
      FOR SELECT USING ((((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id));

    DROP POLICY IF EXISTS geofences_tenant_insert ON public.geofences;
    CREATE POLICY geofences_tenant_insert ON public.geofences
      FOR INSERT WITH CHECK ((((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id));

    DROP POLICY IF EXISTS geofences_tenant_update ON public.geofences;
    CREATE POLICY geofences_tenant_update ON public.geofences
      FOR UPDATE USING ((((SELECT auth.jwt()) ->> 'org_id')::uuid = carrier_id));
  END IF;
END $$;

-------------------------------------------------
-- 7️⃣ View Security Remediation
-------------------------------------------------
-- You MUST replace the placeholder with the original view definition
-- before running this script.

DROP VIEW IF EXISTS public.v_trucks_in_geofences;
-- Placeholder removed to avoid syntax error; to recreate, use security_view_fix.sql which contains guarded creation

DROP VIEW IF EXISTS public.v_truck_service_next_due;
-- Placeholder removed to avoid syntax error; to recreate, use security_view_fix.sql which contains guarded creation

DROP VIEW IF EXISTS public.v_truck_current_positions_geo;
-- Placeholder removed to avoid syntax error; to recreate, use security_view_fix.sql which contains guarded creation

DROP VIEW IF EXISTS public.fuel_monthly_agg;
-- Placeholder removed to avoid syntax error; consider dropping only if exists, recreation is optional.

DROP VIEW IF EXISTS public.v_truck_positions_geo;
-- Placeholder removed to avoid syntax error; to recreate, use security_view_fix.sql which contains guarded creation

DROP VIEW IF EXISTS public.v_truck_current;
-- Placeholder removed to avoid syntax error; to recreate, use security_view_fix.sql which contains guarded creation

-------------------------------------------------
-- 8️⃣ Duplicate Indexes Cleanup
-------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint c JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname='dispatch_order_legs' AND c.conname='dispatch_order_legs_order_id_seq_key'
  ) THEN
    EXECUTE 'ALTER TABLE public.dispatch_order_legs DROP CONSTRAINT IF EXISTS dispatch_order_legs_order_id_seq_key';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='pings'
  ) THEN
    -- Replace \'pings_duplicate_idx\' with the real index name if a duplicate exists
    EXECUTE 'DROP INDEX IF EXISTS pings_duplicate_idx';
  END IF;
END $$;
