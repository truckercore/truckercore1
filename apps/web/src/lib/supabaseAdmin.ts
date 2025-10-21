import { createClient } from "@supabase/supabase-js";

export const supabaseAdmin = createClient(
  (process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL) as string,
  (process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.SUPABASE_SERVICE_ROLE ||
    process.env.SUPABASE_SERVICE_KEY) as string,
  { auth: { persistSession: false } }
);
