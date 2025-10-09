import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

/**
 * Health check endpoint for api.truckercore.com
 * Returns 200 OK with system status and timestamp
 */
serve(async (req) => {
  const url = new URL(req.url);
  
  // CORS headers for browser requests
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  } as Record<string, string>;

  // Handle OPTIONS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  // Only allow GET
  if (req.method !== "GET") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Check if detailed health info requested
  const detailed = url.searchParams.get("detailed") === "true";

  const healthData: Record<string, any> = {
    status: "healthy",
    timestamp: new Date().toISOString(),
    service: "TruckerCore API",
    version: Deno.env.get("APP_VERSION") || "1.0.0",
  };

  if (detailed) {
    // Optional: Add more health checks
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const hasServiceKey = !!Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    healthData.checks = {
      environment: {
        supabase_configured: !!supabaseUrl,
        service_key_present: hasServiceKey,
      },
      uptime: Deno.metrics().ops.op_host_recv_ctrl.count > 0,
    } as Record<string, any>;

    // Optional: Ping Supabase to verify connectivity
    if (supabaseUrl && hasServiceKey) {
      try {
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
        const pingStart = Date.now();
        const res = await fetch(`${supabaseUrl}/rest/v1/`, {
          method: "HEAD",
          headers: {
            apikey: serviceKey!,
            Authorization: `Bearer ${serviceKey}`,
          },
          signal: AbortSignal.timeout(3000), // 3s timeout
        });
        const pingDuration = Date.now() - pingStart;
        healthData.checks.database = {
          reachable: res.ok,
          latency_ms: pingDuration,
        };
      } catch (error) {
        healthData.checks.database = {
          reachable: false,
          error: error instanceof Error ? error.message : "Unknown error",
        };
      }
    }
  }

  return new Response(JSON.stringify(healthData, null, 2), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-cache, no-store, must-revalidate",
    },
  });
});