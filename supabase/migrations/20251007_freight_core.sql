-- Freight Management System - Core Schema Migration
-- Created: 2025-10-07
-- Purpose: Create core freight tables matching apps/web/src/types/freight.ts and
--          owner-operator finance tables matching src/types/ownerOperator.ts
-- Rollback: See DROP statements at bottom (execute in reverse order)

-- ===============================
-- SCHEMA: PUBLIC TABLES
-- ===============================

-- Carriers
CREATE TABLE IF NOT EXISTS public.carriers (
  id text PRIMARY KEY,
  company_name text NOT NULL,
  mc_number text NOT NULL,
  dot_number text NOT NULL,
  contact_name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  status text NOT NULL CHECK (status IN ('pending','approved','rejected','suspended')),
  rating numeric NOT NULL DEFAULT 0,
  total_loads integer NOT NULL DEFAULT 0,
  on_time_delivery_rate numeric NOT NULL DEFAULT 0,
  insurance_verified boolean NOT NULL DEFAULT false,
  insurance_expiry timestamptz,
  authority_status text NOT NULL DEFAULT 'active' CHECK (authority_status IN ('active','inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS carriers_status_idx ON public.carriers(status);
CREATE INDEX IF NOT EXISTS carriers_mc_idx ON public.carriers(mc_number);

-- Loads
CREATE TABLE IF NOT EXISTS public.loads (
  id text PRIMARY KEY,
  customer_id text NOT NULL,
  customer_name text NOT NULL,
  carrier_id text REFERENCES public.carriers(id) ON UPDATE CASCADE ON DELETE SET NULL,
  carrier_name text,
  status text NOT NULL CHECK (status IN ('posted','assigned','in_transit','delivered','cancelled')),
  pickup_address text NOT NULL,
  pickup_city text NOT NULL,
  pickup_state text NOT NULL,
  pickup_zip text NOT NULL,
  delivery_address text NOT NULL,
  delivery_city text NOT NULL,
  delivery_state text NOT NULL,
  delivery_zip text NOT NULL,
  pickup_date timestamptz NOT NULL,
  delivery_date timestamptz NOT NULL,
  equipment_type text NOT NULL CHECK (equipment_type IN ('dry_van','reefer','flatbed','step_deck','tanker')),
  weight integer NOT NULL,
  distance integer NOT NULL,
  commodity text NOT NULL,
  customer_rate numeric NOT NULL,
  carrier_rate numeric,
  margin numeric,
  margin_percentage numeric,
  special_instructions text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS loads_status_idx ON public.loads(status);
CREATE INDEX IF NOT EXISTS loads_customer_idx ON public.loads(customer_id);
CREATE INDEX IF NOT EXISTS loads_carrier_idx ON public.loads(carrier_id);

-- Load Documents
CREATE TABLE IF NOT EXISTS public.load_documents (
  id text PRIMARY KEY,
  load_id text NOT NULL REFERENCES public.loads(id) ON UPDATE CASCADE ON DELETE CASCADE,
  doc_type text NOT NULL CHECK (doc_type IN ('rate_confirmation','bol','pod','invoice','other')),
  file_name text NOT NULL,
  file_url text NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  uploaded_by text NOT NULL
);

CREATE INDEX IF NOT EXISTS load_documents_load_idx ON public.load_documents(load_id);

-- Invoices (broker/customer)
CREATE TABLE IF NOT EXISTS public.invoices (
  id text PRIMARY KEY,
  load_id text NOT NULL REFERENCES public.loads(id) ON UPDATE CASCADE ON DELETE CASCADE,
  customer_id text NOT NULL,
  amount numeric NOT NULL,
  status text NOT NULL CHECK (status IN ('draft','sent','paid','overdue')),
  issue_date timestamptz NOT NULL,
  due_date timestamptz NOT NULL,
  paid_date timestamptz,
  payment_method text
);

CREATE INDEX IF NOT EXISTS invoices_status_idx ON public.invoices(status);
CREATE INDEX IF NOT EXISTS invoices_customer_idx ON public.invoices(customer_id);

-- ===============================
-- OWNER-OPERATOR FINANCE TABLES
-- ===============================

-- Revenues
CREATE TABLE IF NOT EXISTS public.oo_revenues (
  id text PRIMARY KEY,
  occurred_at timestamptz NOT NULL,
  load_id text,
  amount numeric NOT NULL,
  miles integer NOT NULL DEFAULT 0,
  description text NOT NULL,
  invoice_number text,
  paid_date timestamptz,
  status text NOT NULL CHECK (status IN ('pending','paid','overdue'))
);

-- Expenses
CREATE TABLE IF NOT EXISTS public.oo_expenses (
  id text PRIMARY KEY,
  occurred_at timestamptz NOT NULL,
  category text NOT NULL CHECK (category IN ('fuel','maintenance','insurance','tolls','permits','depreciation','meals','lodging','other')),
  amount numeric NOT NULL,
  description text NOT NULL,
  receipt_url text,
  mileage numeric,
  fuel_gallons numeric,
  state text,
  deductible boolean NOT NULL DEFAULT true
);

-- IFTA supporting tables (simplified)
CREATE TABLE IF NOT EXISTS public.ifta_trips (
  id bigserial PRIMARY KEY,
  state text NOT NULL,
  miles numeric NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ifta_fuel_purchases (
  id bigserial PRIMARY KEY,
  state text NOT NULL,
  gallons numeric NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

-- ===============================
-- ANALYTICS VIEWS
-- ===============================

CREATE OR REPLACE VIEW public.v_loads_by_status AS
SELECT status, count(*) AS count
FROM public.loads
GROUP BY status;

CREATE OR REPLACE VIEW public.v_revenue_by_customer AS
SELECT customer_id, customer_name, sum(customer_rate) AS revenue
FROM public.loads
GROUP BY customer_id, customer_name;

-- ===============================
-- BASIC RLS (optional; enable when policies ready)
-- ===============================
-- NOTE: Enable RLS only after setting proper policies for your auth model
-- ALTER TABLE public.carriers ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.loads ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.load_documents ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.oo_revenues ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.oo_expenses ENABLE ROW LEVEL SECURITY;

-- ===============================
-- ROLLBACK (manual)
-- ===============================
-- DROP VIEW IF EXISTS public.v_revenue_by_customer;
-- DROP VIEW IF EXISTS public.v_loads_by_status;
-- DROP TABLE IF EXISTS public.ifta_fuel_purchases;
-- DROP TABLE IF EXISTS public.ifta_trips;
-- DROP TABLE IF EXISTS public.oo_expenses;
-- DROP TABLE IF EXISTS public.oo_revenues;
-- DROP TABLE IF EXISTS public.invoices;
-- DROP TABLE IF EXISTS public.load_documents;
-- DROP TABLE IF EXISTS public.loads;
-- DROP TABLE IF EXISTS public.carriers;
