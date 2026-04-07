Deno.serve(() =>
  new Response(
    JSON.stringify({
      schemas: ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
      totalResults: 2,
      startIndex: 1,
      itemsPerPage: 2,
      Resources: [
        {
          id: "User",
          name: "User",
          endpoint: "/scim/v2/Users",
          schema: "urn:ietf:params:scim:schemas:core:2.0:User",
          schemas: [
            "urn:ietf:params:scim:schemas:core:2.0:ResourceType",
          ],
        },
        {
          id: "Group",
          name: "Group",
          endpoint: "/scim/v2/Groups",
          schema: "urn:ietf:params:scim:schemas:core:2.0:Group",
          schemas: [
            "urn:ietf:params:scim:schemas:core:2.0:ResourceType",
          ],
        },
      ],
    }),
    { headers: { "content-type": "application/scim+json" } },
  )
);
