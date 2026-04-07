import { openDB } from "idb";

const DB = await openDB("truckercore-offline", 2, { upgrade(db, oldV) {
  if (!db.objectStoreNames.contains("queue")) db.createObjectStore("queue", { keyPath: "id" });
  if (!db.objectStoreNames.contains("files")) db.createObjectStore("files", { keyPath: "id" });
}});

export async function enqueueFile(file: File, meta: { orgId: string; loadId: string; path: string }) {
  const id = crypto.randomUUID();
  const buf = await file.arrayBuffer();
  await DB.put("files", { id, meta, bytes: new Uint8Array(buf) });
  return id;
}

export async function flushFiles(createSignedUrl: (path:string)=>Promise<string>) {
  const tx = DB.transaction(["files"], "readwrite");
  const store = tx.objectStore("files");
  // @ts-ignore – iterate all
  for await (const cursor of store) {
    const { id, meta, bytes } = cursor.value as any;
    const url = await createSignedUrl(meta.path);
    await fetch(url, { method: "PUT", body: bytes });
    await store.delete(id);
  }
  await tx.done;
}
