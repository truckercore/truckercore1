import type { TTSEngine, TtsOptions } from '../contracts';

export class Mimic3GatewayTTSEngine implements TTSEngine {
  readonly name = 'mimic3-gateway';
  readonly offline = false;

  private base = '/api/tts/speak';

  async init() {}
  async speak(text: string, opts?: TtsOptions) {
    const res = await fetch(this.base, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text, locale: opts?.locale ?? 'en-US', voice: opts?.voice, rate: opts?.rate }),
    });
    if (!res.ok) throw new Error('TTS failed');
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = new Audio(url);
    await a.play();
  }
  cancel() { /* managed by Audio element */ }
}
