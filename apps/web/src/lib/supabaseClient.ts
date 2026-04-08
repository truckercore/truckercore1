import { createClient } from './supabase/client';

// Single browser client factory (unified): prefer importing from '@/lib/supabase'
export const supabase = createClient();
