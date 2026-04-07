export type ApiErrorCode =
  | "bad_request" | "unauthorized" | "forbidden" | "not_found"
  | "conflict" | "rate_limited" | "invalid_state"
  | "internal_error";

export function reqId(): string {
  // Fallback for environments lacking crypto.randomUUID
  // deno-lint-ignore no-explicit-any
  const anyCrypto: any = (globalThis as any).crypto;
  if (anyCrypto?.randomUUID) return anyCrypto.randomUUID();
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 10);
}

export function ok<T>(data: T, requestId?: string) {
  return new Response(JSON.stringify({ status: "ok", data, requestId: requestId ?? reqId() }), {
    headers: { "Content-Type": "application/json" }, status: 200
  });
}

export function err(code: ApiErrorCode, message: string, requestId?: string, httpStatus?: number) {
  return new Response(JSON.stringify({ status: "error", code, message, requestId: requestId ?? reqId() }), {
    headers: { "Content-Type": "application/json" },
    status: httpStatus ?? (code === "internal_error" ? 500 : 400)
  });
}

// Back-compat helpers used by older functions
export function json<T>(data: T, requestId?: string) {
  return ok(data, requestId);
}
export function bad(status: number, code: ApiErrorCode | string, message?: string, requestId?: string) {
  const c = (code as ApiErrorCode);
  const msg = message ?? (typeof code === 'string' ? code : 'error');
  const httpStatus = status || (c === 'internal_error' ? 500 : 400);
  return err(c, msg, requestId, httpStatus);
}

// Wrap a handler to inject a requestId and map unknowns to internal_error
export function withApiShape(handler: (req: Request, ctx: {requestId: string}) => Promise<Response> | Response) {
  return async (req: Request) => {
    const requestId = req.headers.get("X-Request-Id") ?? reqId();
    try {
      const r = await handler(req, { requestId });
      const ct = r.headers.get("Content-Type") || r.headers.get("content-type") || "";
      if (ct.includes("application/json")) return r;
      const text = await r.text();
      return ok(text as unknown as string, requestId);
    } catch (e: unknown) {
      const msg = (e && typeof (e as any).message === "string") ? (e as any).message : "Unexpected error";
      return err("internal_error", msg, requestId, 500);
    }
  };
}
