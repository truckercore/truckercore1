Env var naming update (2025-09)

- Supabase Edge Functions: Prefer SUPABASE_ANON. A compatibility fallback to SUPABASE_ANON_KEY remains in code paths with a console.warn deprecation message. Please migrate your environment configs to SUPABASE_ANON.
- Web (Next.js): Public clients should continue to use NEXT_PUBLIC_SUPABASE_ANON_KEY. No change required.
- Flutter/mobile builds: When passing env via --dart-define or CI, prefer SUPABASE_ANON alongside SUPABASE_URL and MAPBOX_TOKEN.

Rationale: Aligns server-side Edge Functions on a non-public variable name while keeping web clients on NEXT_PUBLIC_*. This reduces confusion between server and public contexts and keeps backwards-compatibility during the transition window.
