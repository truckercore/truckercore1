// TypeScript
import { cookies } from "next/headers";
import { createServerClient } from "@supabase/ssr";

export function supabaseServerClient() {
  const cookieStore = cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value;
        },
      },
    }
  );
}

export async function getUserAndClaims() {
  const supabase = supabaseServerClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) return { user: null, claims: null };
  const claims = {
    app_role: (user.app_metadata as any)?.app_role ?? (user.user_metadata as any)?.app_role,
    app_org_id: (user.app_metadata as any)?.app_org_id ?? (user.user_metadata as any)?.app_org_id,
  };
  return { user, claims };
}
