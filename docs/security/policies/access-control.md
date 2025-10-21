# Access Control Policy (Skeleton)

Purpose: Define roles, responsibilities, and access controls. Enforce SSO and least privilege.

Scope: Engineering, Operations, and Customer Support systems.

Roles: corp_admin, regional_manager, location_manager, fleet_manager, dispatcher, safety, broker, driver.

Controls:
- SSO required for admin access; MFA recommended via IdP
- Role-based access control; quarterly reviews
- Joiner/Mover/Leaver workflow documented
- Service accounts scoped; keys rotated regularly

Evidence: quarterly review report, access change tickets, audit logs.
