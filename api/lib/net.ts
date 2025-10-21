// api/lib/net.ts
// Minimal SSRF guard and safe fetch utility

import dns from 'dns/promises';
import net from 'net';

export interface SafeFetchPolicy {
  allowHosts?: string[]; // optional explicit allowlist of hostnames
}

function isPrivateOrLocal(ip: string): boolean {
  if (net.isIPv4(ip)) {
    const parts = ip.split('.').map((x) => parseInt(x, 10));
    const [a, b] = parts;
    if (a === 10) return true; // 10.0.0.0/8
    if (a === 127) return true; // loopback
    if (a === 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
    if (a === 192 && b === 168) return true; // 192.168.0.0/16
    if (a === 169 && b === 254) return true; // link-local
    return false;
  } else if (net.isIPv6(ip)) {
    const v = ip.toLowerCase();
    if (v === '::1') return true; // loopback
    if (v.startsWith('fc') || v.startsWith('fd')) return true; // fc00::/7 unique local
    if (v.startsWith('fe80')) return true; // link-local
    return false;
  }
  return true; // unknown: block
}

export async function assertUrlIsSafe(urlStr: string, policy?: SafeFetchPolicy): Promise<void> {
  let url: URL;
  try {
    url = new URL(urlStr);
  } catch {
    throw new Error('unsafe_url:bad_url');
  }
  if (url.protocol !== 'https:') {
    throw new Error('unsafe_url:non_https');
  }
  if (policy?.allowHosts && policy.allowHosts.length > 0) {
    const hostAllowed = policy.allowHosts.includes(url.hostname);
    if (!hostAllowed) throw new Error('unsafe_url:host_not_allowlisted');
  }
  // Resolve host and validate IPs are public
  try {
    const addrs = await dns.lookup(url.hostname, { all: true });
    for (const a of addrs) {
      if (isPrivateOrLocal(a.address)) {
        throw new Error('unsafe_url:private_address');
      }
    }
  } catch (e) {
    if (e instanceof Error && e.message.startsWith('unsafe_url:')) throw e;
    // DNS errors: be conservative and fail
    throw new Error('unsafe_url:dns_failure');
  }
}
