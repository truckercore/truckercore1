'use client';

import { createContext, useContext, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import type { Session, User } from "@supabase/supabase-js";

interface SupabaseContextType {
  supabase: typeof supabase;
  user: User | null;
  profile: any | null; // adjust to your schema
}

const SupabaseContext = createContext<SupabaseContextType | undefined>(undefined);

export const SupabaseProvider = ({ children }: { children: React.ReactNode }) => {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<any | null>(null);

  useEffect(() => {
    let alive = true;

    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!alive) return;
      setSession(data.session ?? null);
      setUser(data.session?.user ?? null);
      await loadProfile();
    })();

    const { data: sub } = supabase.auth.onAuthStateChange(async (_event, s) => {
      if (!alive) return;
      setSession(s);
      setUser(s?.user ?? null);
      await loadProfile();
    });

    async function loadProfile() {
      const { data: u } = await supabase.auth.getUser();
      const uid = u.user?.id;
      if (!uid) {
        if (alive) setProfile(null);
        return;
      }
      // Adjust to your actual profile source; here we read profiles if present
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", uid)
        .maybeSingle();
      if (!alive) return;
      if (error) {
        // Fallback to auth user shape
        setProfile({ id: uid, email: u.user?.email });
      } else {
        setProfile({ ...data, email: u.user?.email });
      }
    }

    return () => {
      alive = false;
      sub?.subscription?.unsubscribe?.();
    };
  }, []);

  const value: SupabaseContextType = { supabase, user, profile };

  return <SupabaseContext.Provider value={value}>{children}</SupabaseContext.Provider>;
};

export const useSupabase = () => {
  const ctx = useContext(SupabaseContext);
  if (!ctx) throw new Error("useSupabase must be used within a SupabaseProvider");
  return ctx;
};
