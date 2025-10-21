# TruckerCore Role Catalog, RBAC Matrix, and Approvals (v1)

This document defines the roles, scopes, permissions, and approval workflow for administrative privilege changes. It also outlines the initial Admin UI spec to manage users, roles, and approvals.

Last updated: 2025-09-19
Owner: Platform/Identity
Status: Draft v1 (publishable)

---

## Role Catalog (org‑scoped unless noted)

- corp_admin
  - Full org control across all locations; billing, SSO, roles; analytics org‑wide.
- regional_manager
  - Manage locations in assigned regions; view analytics in regional scope.
- location_manager
  - Manage assigned location(s): parking, fuel, promos, scanner, reviews.
- fleet_manager
  - Manage fleet drivers/loads; view HOS/compliance; no billing.
- dispatcher
  - Assign loads; view all drivers in org; limited settings.
- safety
  - View HOS/violations/inspections; create safety actions; read‑only billing.
- driver
  - Own loads/HOS/inspections; report parking/weigh; redeem promos.
- broker
  - Post/manage loads; offers/negotiation; limited analytics (broker scope).
- admin (platform super‑admin; internal only)
  - Tenancy ops, feature flags, support.

Scope model
- Organization (org) → Region(s) (subset of org) → Location(s)
- Some roles (regional_manager, location_manager) must always carry scope bindings.
- Drivers and brokers are not allowed to set scopes; their scope is implicit (self or broker account).

---

## High‑Level RBAC Matrix (CRUD and scope)

Legend: R = Read, C = Create, U = Update, D = Delete, (scope) = scope basis.

- Org settings (SSO, billing)
  - corp_admin: R/C/U/D (org)
  - safety: R only (billing read‑only)

- Locations CRUD
  - corp_admin: C/U/D (org)
  - regional_manager: C/U for locations in assigned regions; no D by default
  - location_manager: U for assigned locations only (metadata, hours); no C/D

- Live Ops (parking/fuel/scanner)
  - location_manager: U (assigned locations)
  - regional_manager: U (regional scope)
  - corp_admin: U (org)

- Promotions CRUD
  - location_manager: C/U (assigned locations)
  - regional_manager: C/U (regional)
  - corp_admin: C/U/D (org)

- Reviews response
  - location_manager/regional_manager/corp_admin: R/U (respecting scope)

- Fleet drivers CRUD
  - fleet_manager: C/U (org)
  - dispatcher: C (invite/create) (org), U limited
  - corp_admin: C/U/D (org)

- Safety data
  - safety: R/C/U (safety actions; HOS/violations/inspections)
  - fleet_manager: R

- Loads (post/assign)
  - broker: C/U (own broker account scope)
  - dispatcher/fleet_manager: C/U (org)

- Analytics (org/region/location)
  - corp_admin: R (org)
  - regional_manager: R (regional)
  - location_manager: R (assigned location)

- Audit log
  - corp_admin: R (org)
  - Writes via system only (Edge/DB functions), never by end‑user directly

- Escrow/payouts (approve)
  - corp_admin: Approve/deny (org)
  - Finance sub‑role optional later

Notes
- Default‑deny: permissions not listed are denied.
- Data writes that change states (e.g., operator overrides) must be audit‑logged.

---

## Approval Workflow for Privilege Changes

Sensitive roles: corp_admin, regional_manager, location_manager, fleet_manager, broker

- Requester submits change
  - Includes: target user, roles to grant/revoke, scope (regions/locations), expiry (optional), reason.
- Approver required: corp_admin (same org)
- On approval
  - Changes applied; effective immediately.
  - Audit log entry with diff and approver.
- Downgrades/removals
  - Single approval (corp_admin).
- Temporary elevation
  - Requires expiry timestamp.
  - Auto‑revert at expiry; alert 24h prior to requester + approver.

Guardrails
- No self‑approval; approver must differ from requester.
- Dual‑control enforced in UI and API (server validates org and distinct actors).
- Impersonation requires separate approval and time‑bound grant.

---

## Admin UI Spec (initial)

Users tab
- Table columns: User, Email, Roles, Locations/Regions, Last login, Status
- Row actions: Edit roles, Revoke, Impersonate (requires approval)

Role editor
- Assign role(s)
- Scope pickers:
  - Regions multi‑select (for regional_manager)
  - Locations multi‑select (for location_manager)
- Expiry (optional)
- Reason/Justification (required for sensitive roles)
- Preview: Effective permissions summary

Approvals inbox
- List pending role changes
- Shows requester, justification, proposed diff
- Actions: Approve / Deny
- Detail panel: audit trail for user and org

Policies view (read‑only)
- Display RBAC matrix and last changes
- Link to full documentation

---

## API & Data Model (outline)

Tables
- fleet_members(org_id, user_id, role, created_at)
- role_scopes(user_id, org_id, role, regions uuid[], locations uuid[], expires_at timestamptz, reason text)
- role_change_requests(id, org_id, requester_user_id, target_user_id, diff jsonb, expires_at timestamptz null, status text, created_at, approved_by uuid null, approved_at timestamptz null)
- audit_log(id, action, entity, entity_id, org_id, actor_user_id, diff, ts)

Flows
- POST role_change.request → inserts role_change_requests (pending)
- POST role_change.approve → validates approver, applies changes to fleet_members/role_scopes, writes audit_log
- Scheduled job to auto‑revert expired grants, notify 24h prior

RLS (high‑level)
- role_change_requests: requester can read own; corp_admin can read/approve in org
- audit_log: org‑scoped read; writes via SECURITY DEFINER function only

---

## Examples (scenarios)

1) Regional manager request
- Request: grant regional_manager to user X with regions [R1, R2] (expiry 90 days)
- Approval: corp_admin approves; changes applied; audit logged

2) Temporary elevation (incident)
- Request: location_manager to user Y for location L123, expires in 48h; reason: outage response
- Approval → Auto‑revert at expiry; alert at T‑24h

3) Broker onboarding
- Request: broker role for user B (broker org); self‑service within broker tenant; corp_admin approval required if cross‑org access

---

## Appendix: Matrix (compact)

- Org Settings: corp_admin
- Locations: corp_admin (C/U/D), regional_manager (C/U in region), location_manager (U assigned)
- Live Ops: location_manager, regional_manager, corp_admin
- Promotions: location_manager (local), regional_manager (regional), corp_admin
- Reviews: location_manager/regional_manager/corp_admin
- Fleet: fleet_manager, dispatcher (create/invite), corp_admin
- Safety: safety (write), fleet_manager (read)
- Loads: broker (own), dispatcher/fleet_manager (org)
- Analytics: corp_admin(org), regional_manager(region), location_manager(location)
- Audit read: corp_admin; writes via system
- Escrow approvals: corp_admin
