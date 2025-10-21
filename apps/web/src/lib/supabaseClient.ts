import { createClient } from '@supabase/supabase-js'
import { config } from '@/lib/env'

// Single browser client factory (unified): prefer importing from '@/lib/supabase'
export const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
})
