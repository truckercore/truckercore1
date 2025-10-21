export async function ensureMicConsent(userId: string, orgId?: string): Promise<boolean> {
  // Replace with real storage (DB or Supabase). LocalStorage demo only.
  try {
    const key = `mic-consent:${orgId ?? 'global'}:${userId}`;
    const consent = typeof window !== 'undefined' ? window.localStorage.getItem(key) : null;
    if (consent === 'true') return true;
    const granted = await showConsentDialog();
    if (granted && typeof window !== 'undefined') window.localStorage.setItem(key, 'true');
    return granted;
  } catch {
    return false;
  }
}

function showConsentDialog(): Promise<boolean> {
  return new Promise((resolve) => {
    try {
      const ok = typeof window !== 'undefined'
        ? window.confirm('Allow microphone for voice features? Audio stays on-device unless your org policy permits uploads.')
        : false;
      resolve(ok);
    } catch {
      resolve(false);
    }
  });
}
