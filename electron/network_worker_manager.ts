import { Worker } from 'worker_threads';
import * as path from 'path';
import { EventEmitter } from 'events';

interface PendingRequest {
  resolve: (value: any) => void;
  reject: (reason?: any) => void;
  timeout: NodeJS.Timeout;
}

export class NetworkWorkerManager extends EventEmitter {
  private workers: Worker[] = [];
  private pending: Map<string, PendingRequest> = new Map();
  private queue: Array<{ id: string; req: any; resolve: any; reject: any }> = [];
  private loads: Map<number, number> = new Map();
  private readonly poolSize: number;
  private readonly maxPerWorker = 10;

  constructor(poolSize = 4) {
    super();
    this.poolSize = Math.max(1, poolSize);
    this.init();
  }

  private init() {
    const workerPath = path.join(__dirname, 'workers', 'network-worker.js');
    for (let i = 0; i < this.poolSize; i++) {
      const w = new Worker(workerPath, { workerData: { type: 'init', workerId: i } });
      w.on('message', (msg) => this.onMessage(i, msg));
      w.on('error', (err) => this.emit('worker-error', { workerId: i, error: err }));
      w.on('exit', (code) => {
        if (code !== 0) {
          this.emit('worker-exit', { workerId: i, code });
          this.restart(i);
        }
      });
      this.workers.push(w);
      this.loads.set(i, 0);
    }
  }

  private restart(i: number) {
    const workerPath = path.join(__dirname, 'workers', 'network-worker.js');
    const w = new Worker(workerPath, { workerData: { type: 'init', workerId: i } });
    w.on('message', (msg) => this.onMessage(i, msg));
    w.on('error', (err) => this.emit('worker-error', { workerId: i, error: err }));
    this.workers[i] = w;
    this.loads.set(i, 0);
  }

  async request(url: string, opts: { method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'; headers?: Record<string, string>; body?: any; timeout?: number; streaming?: boolean } = {}): Promise<any> {
    const id = this.makeId();
    const req = { id, url, method: opts.method ?? 'GET', headers: opts.headers, body: opts.body, timeout: opts.timeout ?? 30000, streaming: opts.streaming ?? false };
    return await new Promise((resolve, reject) => {
      const workerId = this.pickWorker();
      if (workerId === -1) {
        this.queue.push({ id, req, resolve, reject });
        return;
      }
      this.send(workerId, id, req, resolve, reject, req.timeout);
    });
  }

  private send(workerId: number, id: string, req: any, resolve: any, reject: any, timeoutMs: number) {
    const w = this.workers[workerId];
    const t = setTimeout(() => {
      this.pending.delete(id);
      reject(new Error('Request timeout'));
      const load = (this.loads.get(workerId) || 1) - 1;
      this.loads.set(workerId, Math.max(0, load));
      this.processQueue();
    }, timeoutMs + 1000);

    this.pending.set(id, { resolve, reject, timeout: t });
    this.loads.set(workerId, (this.loads.get(workerId) || 0) + 1);
    w.postMessage(req);
  }

  private onMessage(workerId: number, msg: any) {
    if (msg?.type === 'progress') {
      this.emit('progress', msg);
      return;
    }
    const pr = this.pending.get(msg.id);
    const load = (this.loads.get(workerId) || 1) - 1;
    this.loads.set(workerId, Math.max(0, load));
    if (!pr) return;
    clearTimeout(pr.timeout);
    this.pending.delete(msg.id);
    if (msg.success) pr.resolve(msg); else pr.reject(new Error(msg.error || 'Request failed'));
    this.processQueue();
  }

  private processQueue() {
    if (this.queue.length === 0) return;
    const workerId = this.pickWorker();
    if (workerId === -1) return;
    const next = this.queue.shift();
    if (next) this.send(workerId, next.id, next.req, next.resolve, next.reject, next.req.timeout ?? 30000);
  }

  private pickWorker(): number {
    let min = Infinity;
    let idx = -1;
    for (const [i, load] of this.loads) {
      if (load < this.maxPerWorker && load < min) {
        min = load;
        idx = i;
      }
    }
    return idx;
  }

  private makeId(): string {
    return `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
  }

  getStats() {
    const loads = Array.from(this.loads.values());
    return {
      poolSize: this.poolSize,
      activeRequests: loads.reduce((s, n) => s + n, 0),
      queuedRequests: this.queue.length,
      pendingRequests: this.pending.size,
      workerLoads: loads,
      averageLoad: loads.length ? loads.reduce((s, n) => s + n, 0) / loads.length : 0,
    };
  }

  async shutdown() {
    for (const w of this.workers) await w.terminate();
    this.workers = [];
    this.pending.clear();
    this.queue = [];
    this.loads.clear();
  }
}
