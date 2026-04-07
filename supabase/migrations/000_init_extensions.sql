-- Enable core extensions
create extension if not exists pgcrypto;
create extension if not exists postgis;
create extension if not exists "uuid-ossp";

-- JSON/utility
create extension if not exists intarray;
create extension if not exists btree_gin;

-- App settings helper (JWT claims access)
-- no-op here; we use current_setting('request.jwt.claims', true)
