// functions/scim/_errors.ts
// Consistent SCIM error response helper
export const scimErr = (detail: string, status = 400, scimType?: string) =>
  new Response(
    JSON.stringify({
      schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"],
      detail,
      status: String(status),
      ...(scimType ? { scimType } : {}),
    }),
    { status, headers: { "content-type": "application/scim+json" } }
  );
