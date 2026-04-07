// lib/net/egress.ts
const ALLOW = [
  /^https:\/\/api\.stripe\.com/,
  /^https:\/\/auth\.login\.microsoftonline\.com/,
  /^https:\/\/www\.okta\.com/,
  /^https:\/\/maps\.example\.com/
];

export async function safeFetch(input: string | URL, init?: RequestInit) {
  const url = typeof input === 'string' ? input : input.toString();
  if (!ALLOW.some((re) => re.test(url))) {
    throw new Error(`egress_denied:${url}`);
  }
  // In Node 18+/Deno, global fetch exists. Fall back if needed.
  // @ts-ignore - runtime provides fetch
  return fetch(input as any, init as any);
}

export { ALLOW };
