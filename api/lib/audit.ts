// api/lib/audit.ts
// Simple best-effort audit logging shim; adapt to your logging/DB as needed.

export async function fnAuditInsert({ entity, entityId, action, meta }: { entity: string; entityId: string; action: string; meta?: any }) {
  try {
    // Replace with DB insert or external logger; keep JSON single-line for log parsers
    const rec = { t: new Date().toISOString(), entity, entityId, action, meta }
    // eslint-disable-next-line no-console
    console.info('[AUDIT]', JSON.stringify(rec))
  } catch (_) {
    // ignore
  }
}
