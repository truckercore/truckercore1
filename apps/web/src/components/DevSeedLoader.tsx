'use client';
import { useEffect } from 'react';
import { loadDevSeedIfPermitted } from '@/services/storage/seedData';

export function DevSeedLoader() {
  useEffect(() => {
    void loadDevSeedIfPermitted();
  }, []);
  return null;
}
