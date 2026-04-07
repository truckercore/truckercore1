export function logInfo(msg: string, ctx: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ level: "info", msg, ...ctx }));
}
export function logWarn(msg: string, ctx: Record<string, unknown> = {}) {
  console.warn(JSON.stringify({ level: "warn", msg, ...ctx }));
}
export function logError(msg: string, ctx: Record<string, unknown> = {}) {
  console.error(JSON.stringify({ level: "error", msg, ...ctx }));
}
