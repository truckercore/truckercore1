type Ctx = { org_id?: string; user_role?: string; feature?: string; requestId?: string };

export function logInfo(msg: string, ctx: Ctx = {}) {
  console.log(JSON.stringify({ level: "info", msg, ...ctx }));
}
export function logWarn(msg: string, ctx: Ctx = {}) {
  console.warn(JSON.stringify({ level: "warn", msg, ...ctx }));
}
export function logErr(msg: string, ctx: Ctx = {}) {
  console.error(JSON.stringify({ level: "error", msg, ...ctx }));
}

export function metric(fn: string, ms: number, status: "ok"|"error", ctx: Ctx = {}) {
  console.log(JSON.stringify({ type: "metric", fn, ms, status, ...ctx }));
}
