'use client';

import { useSupabase } from "@/contexts/SupabaseContext";

export const useProfile = () => {
  const { profile } = useSupabase();
  return profile;
};
