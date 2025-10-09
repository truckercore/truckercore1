// functions/scim/_etag.ts
export function weakEtag(id: string, updatedAt: string) {
  const raw = new TextEncoder().encode(`${id}|${updatedAt}`);
  // Deno crypto subtle sync not available for hashing raw; use built-in digest
  // @ts-ignore
  const buf = crypto.subtle.digestSync ? crypto.subtle.digestSync("SHA-256", raw) : null;
  // Fallback simple hash if digestSync not available
  let hex = "";
  if (buf) {
    const u8 = new Uint8Array(buf);
    hex = Array.from(u8).map((b) => b.toString(16).padStart(2, "0")).join("");
  } else {
    let h = 0;
    for (let i = 0; i < raw.length; i++) h = (h * 31 + raw[i]) >>> 0;
    hex = h.toString(16).padStart(8, "0");
  }
  return `W/"${hex.slice(0, 16)}"`;
}

export function assertIfMatch(req: Request, etag: string) {
  const m = req.headers.get("if-match");
  if (!m || m !== etag) {
    const body = {
      schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"],
      detail: "ETag mismatch",
      status: "412",
    };
    throw new Response(JSON.stringify(body), {
      status: 412,
      headers: { "content-type": "application/scim+json" },
    });
  }
}
