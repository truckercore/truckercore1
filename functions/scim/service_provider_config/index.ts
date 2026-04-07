Deno.serve(() =>
  new Response(
    JSON.stringify({
      schemas: [
        "urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig",
      ],
      patch: { supported: true },
      bulk: { supported: false },
      filter: { supported: true, maxResults: 200 },
      changePassword: { supported: false },
      sort: { supported: false },
      etag: { supported: true },
      authenticationSchemes: [
        {
          type: "oauthbearertoken",
          name: "OAuth Bearer Token",
          description: "Bearer token from IdP (SCIM token)",
          primary: true,
        },
      ],
    }),
    { headers: { "content-type": "application/scim+json" } },
  )
);
