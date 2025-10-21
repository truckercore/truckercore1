// Common HTTP helpers for Edge Functions: uniform envelope, request IDs, idempotency
// Response envelope: { ok: boolean, data?: any, error?: { code: string, message: string }, request_id: string, next_cursor?: string }

export type Envelope = {
  ok: boolean;
  data?: unknown;
  error?: { code: string; message: string } | null;
  request_id: string;
  next_cursor?: string | null;
};

export function makeRequestId(req?: Request): string {
  // Prefer client-provided header for trace continuity
  const h = req?.headers?.get('x-request-id');
  try {
    return h && h.length > 0 ? h : crypto.randomUUID();
  } catch {
    // crypto.randomUUID not available in some runtimes
    return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  }
}

export function idempotencyKey(req?: Request): string | undefined {
  const k = req?.headers?.get('Idempotency-Key') || req?.headers?.get('idempotency-key');
  return k ?? undefined;
}

export function ok(body: unknown, request_id: string, extraHeaders?: HeadersInit, next_cursor?: string | null): Response {
  const env: Envelope = { ok: true, data: body, error: null, request_id, next_cursor: next_cursor ?? undefined };
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    'x-request-id': request_id,
    ...(extraHeaders || {}),
  };
  return new Response(JSON.stringify(env), { headers, status: 200 });
}

export function badRequest(message: string, request_id: string, code = 'bad_request', extraHeaders?: HeadersInit): Response {
  const env: Envelope = { ok: false, error: { code, message }, request_id };
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    'x-request-id': request_id,
    ...(extraHeaders || {}),
  };
  return new Response(JSON.stringify(env), { headers, status: 400 });
}

export function error(message: string, request_id: string, status = 500, code = 'server_error', extraHeaders?: HeadersInit): Response {
  const env: Envelope = { ok: false, error: { code, message }, request_id };
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    'x-request-id': request_id,
    ...(extraHeaders || {}),
  };
  return new Response(JSON.stringify(env), { headers, status });
}
