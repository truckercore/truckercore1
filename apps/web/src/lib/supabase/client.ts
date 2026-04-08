import { createClient as createSupabaseClient } from '@supabase/supabase-js';

let client: ReturnType<typeof createSupabaseClient> | null = null;

export function createClient() {
  if (client) return client;
  
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  
  if (!url || !key) {
    console.error('Missing Supabase env vars');
    // Return a dummy client that won't crash
    return createSupabaseClient('https://placeholder.supabase.co', 'placeholder');
  }
  
  client = createSupabaseClient(url, key);
  return client;
}
