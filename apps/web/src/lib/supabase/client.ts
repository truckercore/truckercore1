import { createClient } from '@supabase/supabase-js';

export const createClientComponentClient = () => {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
};

export const createClientClient = () => createClientComponentClient();

// Add createClient for backward compatibility/simplicity in the login page
export const createClientDefault = () => createClientComponentClient();

export { createClientDefault as createClient };
