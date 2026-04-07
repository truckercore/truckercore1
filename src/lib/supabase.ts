import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.REACT_APP_SUPABASE_URL as string;
const supabaseAnonKey = process.env.REACT_APP_SUPABASE_ANON_KEY as string;

if (!supabaseUrl || !supabaseAnonKey) {
  // Keep console-only to avoid crashing builds; CI can enforce presence.
  // eslint-disable-next-line no-console
  console.warn("Supabase env not set: REACT_APP_SUPABASE_URL / REACT_APP_SUPABASE_ANON_KEY");
}

export const supabase = createClient(supabaseUrl ?? "", supabaseAnonKey ?? "");
