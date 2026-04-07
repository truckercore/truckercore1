# Migration Notes: SUPABASE_ANON standardization

What changed:
- SUPABASE_ANON is the preferred anon key variable.
- SUPABASE_ANON_KEY is deprecated. It remains supported as a fallback temporarily.
- Web continues to use NEXT_PUBLIC_SUPABASE_ANON_KEY.

Action items:
- Update local dev and CI to export/use SUPABASE_ANON.
- Keep legacy SUPABASE_ANON_KEY only where fallback is required.

Timeline:
- Current: Deprecation warnings on fallback.
- Future: SUPABASE_ANON_KEY fallback will be removed after the deprecation window (date TBA in release notes).

Testing:
- Ensure runtime initializes Supabase before client access.
- Verify no new direct references to SUPABASE_ANON_KEY are introduced (CI guardrail).
