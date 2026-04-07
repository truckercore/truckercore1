import { Worker } from 'worker_threads';
import * as path from 'path';

export interface WorkerTask<TReq = any, TRes = any> {
  id: string;
  payload: TReq;
  resolve: (value: TRes) => void;
  reject: (error: any) => void;
  timeoutHandle?: NodeJS.Timeout;
}

/**
 * Minimal worker thread pool for offloading CPU or network I/O wrappers.
 * Workers are expected to be JS files that accept messages and post results.
 */
export class WorkerPool<TReq = any, TRes = any> {
  private workers: Worker[] = [];
  private inFlight: Map<string, WorkerTask<TReq, TRes>> = new Map();
  private queue: Array<{ id: string; payload: TReq }> = [];
  private idx = 0;

  constructor(private scriptPath: string, private size: number = Math.max(2, require('os').cpus().length / 2 | 0)) {
    this.scriptPath = path.resolve(scriptPath);
    for (let i = 0; i < this.size; i++) {
      this.spawn(i);
    }
  }

  private spawn(i: number) {
    const w = new Worker(this.scriptPath);
    w.on('message', (msg: any) => this.onMessage(i, msg));
    w.on('error', (err) => this.onError(i, err));
    w.on('exit', (code) => {
      if (code !== 0) this.spawn(i);
    });
    this.workers[i] = w;
  }

  submit(payload: TReq, timeoutMs: number = 30000): Promise<TRes> {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    return new Promise<TRes>((resolve, reject) => {
      const task: WorkerTask<TReq, TRes> = { id, payload, resolve, reject };
      if (timeoutMs > 0) {
        task.timeoutHandle = setTimeout(() => {
          this.inFlight.delete(id);
          reject(new Error('Worker task timeout'));
        }, timeoutMs);
      }
      this.inFlight.set(id, task as any);
      this.dispatch({ id, payload });
    });
  }

  private dispatch(task: { id: string; payload: TReq }) {
    if (this.workers.length === 0) {
      this.queue.push(task);
      return;
    }
    const w = this.workers[this.idx++ % this.workers.length];
    w.postMessage(task);
  }

  private onMessage(_i: number, msg: { id: string; success: boolean; data?: any; error?: any }) {
    const task = this.inFlight.get(msg.id);
    if (!task) return;
    if (task.timeoutHandle) clearTimeout(task.timeoutHandle);
    this.inFlight.delete(msg.id);
    if (msg.success) task.resolve(msg.data as any);
    else task.reject(msg.error);

    // process queued if any
    const next = this.queue.shift();
    if (next) this.dispatch(next);
  }

  private onError(_i: number, err: any) {
    // bubble up errors to all inflight if needed
    // (keep minimal; tasks will timeout)
    // eslint-disable-next-line no-console
    console.error('[WorkerPool] Worker error', err);
  }

  async shutdown() {
    for (const w of this.workers) {
      try { await w.terminate(); } catch {}
    }
    this.workers = [] as any;
    this.inFlight.clear();
    this.queue = [];
  }
}
