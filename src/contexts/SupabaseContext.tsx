import React, { createContext, useContext } from "react";
import { supabase } from "../lib/supabase";

const SupabaseContext = createContext(supabase);

export const SupabaseProvider: React.FC<React.PropsWithChildren> = ({ children }) => {
  return <SupabaseContext.Provider value={supabase}>{children}</SupabaseContext.Provider>;
};

export const useSupabase = () => useContext(SupabaseContext);
