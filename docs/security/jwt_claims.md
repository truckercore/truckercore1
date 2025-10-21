# JWT claim schema for TruckerCore

The auth layer must issue JWTs with the following custom claims used by Postgres RLS policies and services:

Required
- app_org_id (string UUID): Organization scope for all org‑scoped tables.
- app_roles (array of string): Set of roles assigned to the user. Values: driver, owner_op, broker, fleet_manager.
- app_primary_role (string): The current active role context on the client (used by Edge Functions or logs).

Optional
- org_permissions (object): Fine‑grained allows within the org (e.g., {"loads.read": true, "locations.write": false}).

Example
```
{
  "sub": "3d8b0d2b-...",
  "email": "driver@example.com",
  "app_org_id": "8e9138b5-...",
  "app_roles": ["driver","owner_op"],
  "app_primary_role": "driver",
  "org_permissions": {
    "alerts.admin": false,
    "webhooks.admin": false
  }
}
```

Database helpers
- public.has_role(text): returns true if app_roles contains the role.

Notes
- RLS policies must never trust headers; only JWT claims are authoritative for DB access.
- Edge Functions may inspect x-app-org-id and x-app-roles headers for convenience, but must still authorize using JWT claims.
