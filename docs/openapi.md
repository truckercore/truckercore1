# TruckerCore Public API (OpenAPI 3.1)

- Spec location: api/openapi.yaml
- Version: 0.1.0 (initial surface)

Usage
- Import into Postman/Insomnia directly from the YAML file.
- Or generate a client SDK using openapi-generator.

Notes
- Security: API Key via `X-Api-Key` header (scoped per org via backend middleware).
- Idempotency: Mutating endpoints accept `Idempotency-Key` header; server should honor 24–72h TTL.
- This surface is intentionally concise; extend as endpoints harden.
