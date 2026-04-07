"use client";
import React, { createContext, useContext, useMemo, useRef, useState } from 'react';
import type { ASREngine, TTSEngine, EngineChoice, BiasEntry, AsrResult } from './contracts';
import { WhisperWasmEngine } from './engines/whisperWasm';
import { CloudEdgeAsrEngine } from './engines/cloudEdgeAsr';
import { WebSpeechTTSEngine } from './engines/webSpeechTts';
import { Mimic3GatewayTTSEngine } from './engines/mimic3Gateway';

type Ctx = {
  asr: ASREngine;
  tts: TTSEngine;
  setBias(bias: BiasEntry[]): void;
  startASR(cb: (r: AsrResult) => void): Promise<void>;
  stopASR(): Promise<void>;
  speak(text: string): Promise<void>;
  cancelSpeak(): void;
};
const SpeechCtx = createContext<Ctx | null>(null);

export function SpeechProvider({ children, choice }: { children: React.ReactNode; choice?: EngineChoice }) {
  const asr = useMemo<ASREngine>(() => {
    const prefer = choice?.asr ?? (typeof navigator !== 'undefined' && navigator.onLine ? 'cloud-edge' : 'whisper-wasm');
    return prefer === 'cloud-edge' ? new CloudEdgeAsrEngine() : new WhisperWasmEngine();
  }, [choice?.asr]);

  const tts = useMemo<TTSEngine>(() => {
    const prefer = choice?.tts ?? 'webspeech';
    return prefer === 'mimic3-gateway' ? new Mimic3GatewayTTSEngine() : new WebSpeechTTSEngine();
  }, [choice?.tts]);

  const biasRef = useRef<BiasEntry[]>([]);
  const [ready, setReady] = useState(false);

  React.useEffect(() => {
    const ctrl = new AbortController();
    (async () => {
      try {
        await Promise.all([
          asr.init(ctrl.signal, { locale: 'en', domainBias: biasRef.current }),
          tts.init(ctrl.signal as any),
        ]);
      } finally {
        setReady(true);
      }
    })();
    return () => ctrl.abort();
  }, [asr, tts]);

  const value: Ctx = {
    asr,
    tts,
    setBias(b) { biasRef.current = b; asr.updateBias?.(b); },
    async startASR(cb) { if (!ready) await asr.init(undefined, { locale: 'en', domainBias: biasRef.current }); await asr.start(cb); },
    async stopASR() { await asr.stop(); },
    async speak(text) { await tts.speak(text); },
    cancelSpeak() { tts.cancel(); }
  };

  return <SpeechCtx.Provider value={value}>{children}</SpeechCtx.Provider>;
}

export function useSpeech() {
  const ctx = useContext(SpeechCtx);
  if (!ctx) throw new Error('useSpeech must be inside SpeechProvider');
  return ctx;
}
