import { createClient } from '@supabase/supabase-js';

// Feature flag to control DB usage
export const ENABLE_DB = (process.env.NEXT_PUBLIC_ENABLE_DB || 'false') === 'true';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL as string | undefined;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY as string | undefined;

export const supabase = ENABLE_DB && SUPABASE_URL && SUPABASE_ANON_KEY
  ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: false } })
  : (null as any);

export function assertDbConfigured() {
  if (!ENABLE_DB) return { ok: false, reason: 'DB feature flag disabled' } as const;
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return { ok: false, reason: 'Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY' } as const;
  }
  return { ok: true } as const;
}
