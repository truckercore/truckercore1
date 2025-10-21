// deno-lint-ignore-file
import type { ASREngine, AsrInitOptions, AsrResult, BiasEntry } from '../contracts';
import { pipeline, env as txEnv, type AutomaticSpeechRecognitionPipeline } from '@xenova/transformers';

txEnv.useBrowserCache = true;

export class WhisperWasmEngine implements ASREngine {
  public readonly name = 'whisper-wasm';
  public readonly offline = true;

  private pipe?: AutomaticSpeechRecognitionPipeline;
  private mediaStream?: MediaStream;
  private audioCtx?: AudioContext;
  private mediaNode?: MediaStreamAudioSourceNode;
  private processor?: ScriptProcessorNode;
  private collecting: Float32Array[] = [];
  private opts?: AsrInitOptions;
  private onResultCb?: (r: AsrResult) => void;
  private bias: BiasEntry[] = [];

  async init(_signal?: AbortSignal, opts?: AsrInitOptions) {
    this.opts = { locale: 'en', model: 'Xenova/whisper-tiny.en', vadSilenceMs: 1200, ...opts };
    this.pipe = await pipeline('automatic-speech-recognition', this.opts.model!, { quantized: true });
  }

  updateBias(bias: BiasEntry[]) { this.bias = bias; }

  async start(onResult: (r: AsrResult) => void) {
    this.onResultCb = onResult;
    this.mediaStream = await navigator.mediaDevices.getUserMedia({ audio: { noiseSuppression: true, echoCancellation: true } });
    this.audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)({ sampleRate: 16000 });
    this.mediaNode = this.audioCtx.createMediaStreamSource(this.mediaStream);
    this.processor = this.audioCtx.createScriptProcessor(4096, 1, 1);
    this.mediaNode.connect(this.processor);
    this.processor.connect(this.audioCtx.destination);

    const startedAt = performance.now();

    this.processor.onaudioprocess = async (e) => {
      const buf = e.inputBuffer.getChannelData(0);
      this.collecting.push(buf.slice(0));
    };

    const interval = window.setInterval(async () => {
      if (!this.collecting.length || !this.pipe) return;
      const samples = concatFloat32(this.collecting);
      this.collecting = [];

      const t0 = performance.now();
      const out = await (this.pipe as any).call(
        { waveform: samples, sample_rate: 16000 },
        {
          chunk_length_s: 15,
          stride_length_s: 5,
          return_timestamps: true,
          language: this.opts?.locale?.split('-')[0],
        }
      );

      const text = applyBias(out.text as string, this.bias);
      onResult({
        text,
        words: out.chunks?.map((c: any) => ({ start: c.timestamp[0], end: c.timestamp[1], word: c.text.trim() })),
        final: true,
        latencyMs: performance.now() - t0 + (t0 - startedAt),
        engine: this.name,
        offline: true,
      });
    }, this.opts?.vadSilenceMs ?? 1200);

    (this as any)._timer = interval;
  }

  async stop() {
    const t = (this as any)._timer as number | undefined;
    if (t) window.clearInterval(t);
    this.processor?.disconnect();
    this.mediaNode?.disconnect();
    await this.audioCtx?.close();
    this.mediaStream?.getTracks().forEach(t => t.stop());
    this.collecting = [];
  }
}

function concatFloat32(chunks: Float32Array[]): Float32Array {
  const length = chunks.reduce((n, a) => n + a.length, 0);
  const res = new Float32Array(length);
  let off = 0;
  for (const c of chunks) { res.set(c, off); off += c.length; }
  return res;
}

function applyBias(text: string, _bias: BiasEntry[]): string {
  let out = text;
  // Placeholder bias application; you can inject phrase boosting here if needed.
  return out;
}
