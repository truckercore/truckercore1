// functions/scim/_scim_util.ts
export const SCIM_CT = "application/scim+json";

export function scimOk(body: any, status = 200, extraHeaders: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": SCIM_CT, "access-control-allow-origin": "*", ...extraHeaders } });
}

export function scimErr(status: number, detail: string) {
  const body = { schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"], detail, status: String(status) };
  return new Response(JSON.stringify(body), { status, headers: { "content-type": SCIM_CT, "access-control-allow-origin": "*" } });
}
