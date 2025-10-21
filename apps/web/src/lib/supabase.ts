import { createClient } from '@supabase/supabase-js'
import { config } from '@/lib/env'

// Unified Supabase browser client factory
// Avoid constructing the client during server/build to prevent missing-env crashes
export const supabase = typeof window === 'undefined'
  ? (null as unknown as ReturnType<typeof createClient>)
  : createClient(config.supabaseUrl || '', config.supabaseAnonKey || '', {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
      },
    })
