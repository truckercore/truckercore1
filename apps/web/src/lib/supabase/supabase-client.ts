import { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/types/database.types';
import { createClient } from './client';

/**
 * Get Supabase client (singleton pattern)
 */
export function getSupabaseClient(): SupabaseClient<Database> {
  return createClient() as SupabaseClient<Database>;
}

/**
 * Get authenticated Supabase client for user
 */
export function getAuthenticatedClient(token: string): SupabaseClient<Database> {
  // Use the wrapper client and then append the token header if possible, 
  // but since createClient returns a singleton, we might need to use the base library for authenticated overrides
  // Or just rely on the session management in the singleton.
  // For now, since this is a specific override, we can keep the local implementation but use the correct env vars.
  
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  const { createClient: createBaseClient } = require('@supabase/supabase-js');

  return createBaseClient(supabaseUrl, supabaseKey, {
    global: {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
    auth: {
      persistSession: false,
    },
  });
}
