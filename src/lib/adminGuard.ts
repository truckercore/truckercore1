import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function requireAdmin() {
  const cookieStore = cookies();
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get: (k) => cookieStore.get(k)?.value,
      },
    }
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Unauthenticated");

  const { data, error } = await supabase
    .from("profiles")
    .select("role")
    .eq("user_id", user.id)
    .single();

  if (error || !data || !["admin", "dispatcher"].includes((data as any).role)) {
    throw new Error("Forbidden");
  }

  return { supabase, user } as const;
}
