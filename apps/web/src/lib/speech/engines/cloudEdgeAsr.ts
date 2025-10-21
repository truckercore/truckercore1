import type { ASREngine, AsrInitOptions, AsrResult } from '../contracts';
import { z } from 'zod';

const Resp = z.object({
  text: z.string(),
  words: z.array(z.object({ start: z.number(), end: z.number(), word: z.string(), confidence: z.number().optional() })).optional(),
  language: z.string().optional(),
});

export class CloudEdgeAsrEngine implements ASREngine {
  public readonly name = 'cloud-edge';
  public readonly offline = false;
  private locale: string = 'en';

  async init(_sig?: AbortSignal, opts?: AsrInitOptions) {
    if (opts?.locale) this.locale = opts.locale;
  }

  async start(onResult: (r: AsrResult) => void) {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const media = new MediaRecorder(stream, { mimeType: 'audio/webm' });
    const chunks: BlobPart[] = [];
    media.ondataavailable = (e) => chunks.push(e.data);
    media.onstop = async () => {
      try {
        const blob = new Blob(chunks, { type: 'audio/webm' });
        const form = new FormData();
        form.append('audio', blob, 'clip.webm');
        form.append('locale', this.locale);

        const res = await fetch('/api/asr/transcribe', { method: 'POST', body: form });
        const json = await res.json();
        const data = Resp.parse(json);
        onResult({ text: data.text, words: data.words, final: true, engine: this.name, offline: false, language: data.language });
      } catch (e) {
        onResult({ text: '', final: true, engine: this.name, offline: false, confidence: 0 });
      } finally {
        stream.getTracks().forEach(t => t.stop());
      }
    };
    media.start();
    setTimeout(() => media.stop(), 6000);
  }

  async stop() { /* one-shot */ }
  updateBias?(_bias: any[]) { /* no-op for cloud */ }
}
