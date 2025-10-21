export type LocaleTag = `${string}-${string}` | string;

export type BiasEntry = {
  phrase: string;
  weight?: number; // 0..1 boost for decoding
};

export type AsrResult = {
  text: string;
  words?: Array<{ start: number; end: number; word: string; confidence?: number }>;
  confidence?: number;           // utterance confidence
  language?: string;
  final: boolean;                // interim vs final
  latencyMs?: number;
  engine: string;
  offline: boolean;
};

export type AsrInitOptions = {
  locale?: LocaleTag;            // e.g., 'en', 'en-US', 'es'
  model?: string;                // e.g., 'whisper-tiny.en'
  domainBias?: BiasEntry[];      // VINs, road names, customer names
  enableNoiseSuppression?: boolean; // RNNoise/worklet switch
  vadSilenceMs?: number;         // endpointing
  maxUtteranceMs?: number;       // safety cutoff
};

export interface ASREngine {
  readonly name: string;
  readonly offline: boolean;
  init(signal?: AbortSignal, opts?: AsrInitOptions): Promise<void>;
  start(onResult: (r: AsrResult) => void): Promise<void>;
  stop(): Promise<void>;
  updateBias?(bias: BiasEntry[]): void;
}

export type TtsOptions = {
  locale?: LocaleTag;
  voice?: string;
  rate?: number;    // 0.5..2
  pitch?: number;   // 0..2
  volume?: number;  // 0..1
  emotion?: 'neutral'|'urgent'|'calm'|'informative';
};

export interface TTSEngine {
  readonly name: string;
  readonly offline: boolean;
  init(signal?: AbortSignal): Promise<void>;
  speak(text: string, opts?: TtsOptions): Promise<void>;
  cancel(): void;
}

export type EngineChoice =
  | { asr: 'whisper-wasm' | 'cloud-edge'; tts: 'webspeech' | 'mimic3-gateway' }
  | Record<string, never>;
