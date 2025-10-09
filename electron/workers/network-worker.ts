import { parentPort, workerData } from 'worker_threads';
import axios, { AxiosRequestConfig } from 'axios';
import { Agent as HttpAgent } from 'http';
import { Agent as HttpsAgent } from 'https';

interface WorkerRequest {
  id: string;
  url: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
  streaming?: boolean;
}

interface WorkerResponse {
  id: string;
  success: boolean;
  statusCode?: number;
  headers?: Record<string, string>;
  data?: any;
  error?: string;
  duration: number;
}

const httpAgent = new HttpAgent({ keepAlive: true, keepAliveMsecs: 30000, maxSockets: 50, maxFreeSockets: 10 });
const httpsAgent = new HttpsAgent({ keepAlive: true, keepAliveMsecs: 30000, maxSockets: 50, maxFreeSockets: 10, rejectUnauthorized: true });

const client = axios.create({ httpAgent, httpsAgent, timeout: 30000, maxContentLength: 100 * 1024 * 1024, maxBodyLength: 100 * 1024 * 1024 });

async function processRequest(request: WorkerRequest): Promise<WorkerResponse> {
  const started = Date.now();
  try {
    const config: AxiosRequestConfig = {
      method: request.method,
      url: request.url,
      headers: request.headers,
      data: request.body,
      timeout: request.timeout ?? 30000,
    };

    if (request.streaming) {
      config.responseType = 'stream';
      const response = await client.request(config);
      const chunks: Buffer[] = [];
      for await (const chunk of response.data) {
        chunks.push(chunk);
        if (parentPort) parentPort.postMessage({ type: 'progress', id: request.id, bytesReceived: chunks.reduce((s, c) => s + c.length, 0) });
      }
      const buf = Buffer.concat(chunks);
      let data: any = buf.toString('utf8');
      try { data = JSON.parse(data); } catch { /* keep string */ }
      return { id: request.id, success: true, statusCode: response.status, headers: response.headers as Record<string, string>, data, duration: Date.now() - started };
    }

    const response = await client.request(config);
    return { id: request.id, success: true, statusCode: response.status, headers: response.headers as Record<string, string>, data: response.data, duration: Date.now() - started };
  } catch (err: any) {
    return { id: request.id, success: false, statusCode: err?.response?.status, error: err?.message || String(err), duration: Date.now() - started };
  }
}

if (parentPort) {
  parentPort.on('message', async (req: WorkerRequest) => {
    const res = await processRequest(req);
    parentPort!.postMessage(res);
  });
}

if (workerData?.type === 'init') {
  // eslint-disable-next-line no-console
  console.log('[NetworkWorker] Initialized');
}
