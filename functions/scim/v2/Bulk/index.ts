Deno.serve((_req) => {
  const body = {
    schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"],
    detail: "Bulk operations are not supported",
    status: "501",
    scimType: "tooMany"
  };
  return new Response(JSON.stringify(body), { status: 501, headers: { "content-type": "application/scim+json" } });
});
