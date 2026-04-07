type Plugin = { name: string; optional?: boolean; init: () => Promise<void> };
export async function initPlugins(plugins: Plugin[], log = console) {
  const results: Array<{name:string; ok:boolean; err?:string; optional?:boolean}> = [];
  for (const p of plugins) {
    try {
      await p.init();
      log.info(`[plugin] ${p.name} initialized`);
      results.push({ name: p.name, ok: true, optional: p.optional });
    } catch (e: any) {
      const msg = e?.message ?? String(e);
      const level = p.optional ? "warn" : "error";
      (log as any)[level](`[plugin] ${p.name} failed: ${msg}`);
      results.push({ name: p.name, ok: false, err: msg, optional: p.optional });
    }
  }
  const failedRequired = results.filter(r => !r.ok && !r.optional).map(r => r.name);
  const failedOptional = results.filter(r => !r.ok && r.optional).map(r => r.name);
  log.info(`[plugin] summary: ok=${results.filter(r=>r.ok).length}, req_failed=${failedRequired.length}, opt_failed=${failedOptional.length}`);
  if (failedRequired.length) throw new Error(`Required plugins failed: ${failedRequired.join(", ")}`);
}
