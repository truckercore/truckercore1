// api/lib/ratelimit.ts
// Rate-limit response headers helper (DX) and Retry-After usage.
export type Bucket = { limit: number; remaining: number; resetEpoch: number };

export function headersFor(bucket: Bucket): Record<string, string> {
  return {
    "X-RateLimit-Limit": String(bucket.limit),
    "X-RateLimit-Remaining": String(Math.max(0, bucket.remaining)),
    "X-RateLimit-Reset": String(bucket.resetEpoch), // unix seconds
  };
}

// Example usage:
// const bucket = await rateLimit(orgId, key, 60, 60)
// if (bucket.remaining < 0) {
//   return new Response(JSON.stringify({ error: 'rate_limited' }), {
//     status: 429,
//     headers: { ...headersFor(bucket), 'Retry-After': String(Math.max(0, bucket.resetEpoch - Math.floor(Date.now()/1000))), 'Content-Type': 'application/json' }
//   })
// }
// return new Response(body, { status: 200, headers: { ...headersFor(bucket), 'Content-Type': 'application/json' } })
