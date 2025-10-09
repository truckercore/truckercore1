export async function sha256Hex(input: string | Uint8Array) {
  const data = typeof input === 'string' ? new TextEncoder().encode(input) : input;
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2,'0')).join('');
}

export async function hmacValid(secret: string, bodyText: string, sigHeader: string | null) {
  if (!sigHeader) return false;
  const expected = await sha256Hex(secret + '.' + bodyText);
  if (expected.length !== sigHeader.length) return false;
  let ok = 0;
  for (let i = 0; i < expected.length; i++) {
    ok |= expected.charCodeAt(i) ^ sigHeader.charCodeAt(i);
  }
  return ok === 0;
}
