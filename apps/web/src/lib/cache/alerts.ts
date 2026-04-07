export async function cacheAlerts(alerts: any[]) {
  const db = await open();
  const tx = db.transaction("alerts", "readwrite");
  for (const a of alerts) {
    await tx.store.put({
      id: crypto.randomUUID(),
      created_at: Date.now(),
      ...a,
    });
  }
  await tx.done;
}

export async function lastAlerts(limit = 10) {
  const db = await open();
  const tx = db.transaction("alerts");
  const all = await tx.store.getAll();
  return all.sort((a: any, b: any) => b.created_at - a.created_at).slice(0, limit);
}

async function open() {
  const { openDB } = await import("idb");
  return openDB("truckercore", 1, {
    upgrade(db) {
      if (!db.objectStoreNames.contains("alerts")) {
        db.createObjectStore("alerts", { keyPath: "id" });
      }
    },
  });
}
