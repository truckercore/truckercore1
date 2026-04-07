import { parentPort } from 'worker_threads';

// Reuse the generic shapes used by the WorkerPool in this package
// This worker expects messages of the form: { id: string; payload: any }
// and will respond with: { id, success, data? , error? }

interface WorkerEnvelope<T = any> {
  id: string;
  payload: T;
}

// Worker script that handles network I/O off the main thread
export interface NetworkRequest {
  url: string;
  method: string;
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
}

async function executeNetworkRequest(request: NetworkRequest): Promise<any> {
  // Prefer Node 18+ built-in fetch; fall back to node-fetch if not available
  const _fetch: typeof fetch = (globalThis as any).fetch
    ? (globalThis as any).fetch
    : (await import('node-fetch')).default as any;

  const controller = new AbortController();
  const timeoutId = request.timeout
    ? setTimeout(() => controller.abort(), request.timeout)
    : null;

  try {
    const response = await _fetch(request.url, {
      method: request.method,
      headers: request.headers,
      body: request.body != null ? JSON.stringify(request.body) : undefined,
      signal: controller.signal as any,
    } as any);

    if (timeoutId) clearTimeout(timeoutId);

    const text = await (response as any).text();
    let data: any;
    try {
      data = text ? JSON.parse(text) : undefined;
    } catch {
      data = text; // non-JSON response
    }

    return {
      status: (response as any).status,
      headers: typeof (response as any).headers?.forEach === 'function'
        ? Object.fromEntries((response as any).headers.entries())
        : (response as any).headers,
      data,
    };
  } catch (error: any) {
    if (timeoutId) clearTimeout(timeoutId);
    throw error;
  }
}

async function transformData(payload: any): Promise<any> {
  // Placeholder for heavy transformations
  return payload;
}

async function batchProcess(payload: any): Promise<any> {
  // Placeholder for batching logic
  return payload;
}

async function processTask(task: WorkerEnvelope): Promise<{ success: boolean; data?: any; error?: string }> {
  try {
    const { type, ...rest } = (task.payload || {}) as any;
    let result: any;

    switch (type) {
      case 'network_request':
        result = await executeNetworkRequest(rest as NetworkRequest);
        break;
      case 'data_transform':
        result = await transformData(rest);
        break;
      case 'batch_process':
        result = await batchProcess(rest);
        break;
      default:
        throw new Error(`Unknown task type: ${type}`);
    }

    return { success: true, data: result };
  } catch (err: any) {
    return { success: false, error: err?.message || String(err) };
  }
}

// Listen for tasks from main thread
if (parentPort) {
  parentPort.on('message', async (task: WorkerEnvelope) => {
    const result = await processTask(task);
    parentPort!.postMessage({ id: task.id, ...result });
  });
}
