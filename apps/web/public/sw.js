// JavaScript
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));

const DB = "offline-telemetry";
const STORE = "telemetryQueue";

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE, { keyPath: "id", autoIncrement: true });
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function putQueue(item) {
  const db = await openDB();
  const tx = db.transaction(STORE, "readwrite");
  tx.objectStore(STORE).add(item);
  return new Promise((res, rej) => { tx.oncomplete = () => res(); tx.onerror = () => rej(tx.error); });
}

async function drainQueue() {
  const db = await openDB();
  const tx = db.transaction(STORE, "readwrite");
  const store = tx.objectStore(STORE);
  const items = [];
  await new Promise((res) => {
    const req = store.openCursor();
    req.onsuccess = () => {
      const cur = req.result;
      if (cur) { items.push({ key: cur.key, val: cur.value }); cur.continue(); } else res();
    };
  });
  for (const it of items) {
    try {
      await fetch("/api/telemetry", { method:"POST", headers:{"content-type":"application/json"}, body: JSON.stringify(it.val) });
      store.delete(it.key);
    } catch { break; }
  }
  await new Promise((res) => { tx.oncomplete = () => res(); });
}

self.addEventListener("fetch", (e) => {
  if (e.request.url.endsWith("/api/telemetry") && e.request.method === "POST") {
    e.respondWith((async () => {
      try {
        return await fetch(e.request.clone());
      } catch {
        const body = await e.request.clone().json();
        await putQueue({ body, ts: Date.now() });
        return new Response(JSON.stringify({ queued:true }), { headers:{"content-type":"application/json"}});
      }
    })());
  }
});

self.addEventListener("sync", (e)=>{ if (e.tag === "drain-telemetry") e.waitUntil(drainQueue()); });
