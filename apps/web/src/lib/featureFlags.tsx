"use client";
import { createContext, useContext, useState, useEffect, ReactNode } from 'react'

export type FeatureFlags = Record<string, boolean>

const FeatureFlagsContext = createContext<FeatureFlags>({})

export function FeatureFlagsProvider({ children, initialFlags = {} }: { children: ReactNode, initialFlags?: FeatureFlags }) {
  const [flags] = useState<FeatureFlags>(initialFlags)
  return (
    <FeatureFlagsContext.Provider value={flags}>{children}</FeatureFlagsContext.Provider>
  )
}

export function useFeatureFlags() {
  return useContext(FeatureFlagsContext)
}
