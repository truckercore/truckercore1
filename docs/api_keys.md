# Public API Keys

Schema: public.api_keys
- id uuid primary key
- org_id uuid not null
- name text not null
- key_hash text not null (store hash only — never the raw key)
- scopes text[] not null (e.g., {'read:loads','write:locations','admin:webhooks'})
- created_at, updated_at, last_used_at
- is_active boolean

RLS: service-managed (locked for end-user direct access). Expose via SECURITY DEFINER functions or API middleware with org-admin checks.

Key format
- Issue keys in the form `tc_live_...` or `tc_test_...` and store only a one-way hash (e.g., sha256). Display the raw key only once on creation.

Scopes
- Recommended scopes:
  - read:loads, write:loads
  - read:trucks, write:locations
  - read:documents, write:documents
  - admin:webhooks, admin:api_keys

Rotation
- Implement `rotate` by creating a new key (new row), returning it to the caller, and marking the old key inactive after a grace period.

Middleware outline
- Look up `Authorization: Bearer <api_key>` by hashing provided key and matching an active row.
- Resolve `org_id` from the row and attach to request context.
- Enforce scopes per endpoint using a simple allow-list.
- Update `last_used_at` asynchronously.

Example (pseudo)
```
const raw = readAuthHeader();
const hash = sha256(raw);
const key = await db.api_keys.findOne({ hash, is_active: true });
if (!key) return 401;
ctx.orgId = key.org_id;
ctx.scopes = key.scopes;
assertScope('write:locations');
```
