'use client';
import { useCallback, useRef, useState } from 'react';
import type { AsrResult, BiasEntry } from './contracts';
import { useSpeech } from './provider';

export function useASR(initialBias?: BiasEntry[]) {
  const { startASR, stopASR, setBias } = useSpeech();
  const [listening, setListening] = useState(false);
  const [last, setLast] = useState<AsrResult | null>(null);
  const stopRef = useRef<() => Promise<void>>(async () => { await stopASR(); setListening(false); });

  const start = useCallback(async () => {
    if (initialBias) setBias(initialBias);
    setListening(true);
    await startASR((r) => setLast(r));
  }, [initialBias, setBias, startASR]);

  const stop = useCallback(async () => stopRef.current(), []);
  return { start, stop, listening, last, setBias };
}

export function useTTS() {
  const { speak, cancelSpeak } = useSpeech();
  return { speak, cancelSpeak };
}
