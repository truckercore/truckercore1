Deno.serve(() =>
  new Response(
    JSON.stringify({
      schemas: ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
      totalResults: 2,
      startIndex: 1,
      itemsPerPage: 2,
      Resources: [
        {
          id: "urn:ietf:params:scim:schemas:core:2.0:User",
          name: "User",
          attributes: [
            { name: "userName", type: "string", required: true, mutability: "readWrite" },
            { name: "externalId", type: "string", required: false, mutability: "readWrite" },
            { name: "active", type: "boolean", required: false, mutability: "readWrite" }
          ],
          schemas: ["urn:ietf:params:scim:schemas:core:2.0:Schema"]
        },
        {
          id: "urn:ietf:params:scim:schemas:core:2.0:Group",
          name: "Group",
          attributes: [
            { name: "displayName", type: "string", required: true, mutability: "readWrite" },
            { name: "members", type: "complex", multiValued: true, mutability: "readWrite" }
          ],
          schemas: ["urn:ietf:params:scim:schemas:core:2.0:Schema"]
        }
      ]
    }),
    { headers: { "content-type": "application/scim+json" } }
  )
);
