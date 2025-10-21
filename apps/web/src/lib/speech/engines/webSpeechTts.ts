import type { TTSEngine, TtsOptions } from '../contracts';

export class WebSpeechTTSEngine implements TTSEngine {
  readonly name = 'webspeech';
  readonly offline = true;

  async init() { /* no-op */ }

  async speak(text: string, opts?: TtsOptions) {
    if (typeof window === 'undefined' || !('speechSynthesis' in window)) throw new Error('Web Speech not supported');
    window.speechSynthesis.cancel();
    const ut = new SpeechSynthesisUtterance(text);
    ut.rate = opts?.rate ?? 1;
    ut.pitch = opts?.pitch ?? 1;
    ut.volume = opts?.volume ?? 1;
    ut.lang = opts?.locale ?? 'en-US';
    if (opts?.voice) {
      const v = speechSynthesis.getVoices().find(v => v.name === opts.voice);
      if (v) ut.voice = v;
    }
    if (opts?.emotion === 'urgent') ut.rate = Math.min(1.25, (opts.rate ?? 1) + 0.2);

    return new Promise<void>(res => { ut.onend = () => res(); window.speechSynthesis.speak(ut); });
  }

  cancel() { if (typeof window !== 'undefined') window.speechSynthesis.cancel(); }
}
