Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });

  try {
    const { depot, vehicles, stops, constraints } = await req.json(); // VRP payload
    const res = await fetch(Deno.env.get("ROUTE_SOLVER_URL")!, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ depot, vehicles, stops, constraints }),
    });

    return new Response(await res.text(), {
      headers: {
        "content-type": "application/json",
        "access-control-allow-origin": "*",
      },
    });
  } catch {
    return new Response("error", { status: 500 });
  }
});
