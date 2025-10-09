// supabase/functions/_shared/validators.ts
// Simple validators for emails and E.164 phone numbers, plus helpers.

export function isEmail(x: unknown): x is string {
  if (typeof x !== 'string') return false;
  const s = x.trim();
  if (!s) return false;
  // Simple RFC5322-light regex
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
}

export function isE164(x: unknown): x is string {
  if (typeof x !== 'string') return false;
  const s = x.trim();
  return /^\+[1-9]\d{6,14}$/.test(s); // E.164 up to 15 digits
}

export function nonEmptyString(x: unknown): x is string {
  return typeof x === 'string' && x.trim().length > 0;
}

export function sanitizePhone(x: unknown): string | null {
  if (typeof x !== 'string') return null;
  const digits = x.replace(/[^\d+]/g, '');
  // If already starts with + and matches E.164, keep
  if (/^\+[1-9]\d{6,14}$/.test(digits)) return digits;
  // If US-like 10 digits, allow +1 prefix heuristic
  const ten = x.replace(/\D/g, '');
  if (ten.length === 10) return `+1${ten}`;
  return null;
}

export function requireContact(email?: unknown, phone?: unknown): { ok: boolean; email?: string; phone?: string; reason?: string } {
  const e = typeof email === 'string' ? email.trim() : '';
  const p = typeof phone === 'string' ? phone.trim() : '';
  if (!e && !p) return { ok: false, reason: 'contact_required' };
  let outEmail: string | undefined;
  let outPhone: string | undefined;
  if (e) {
    if (!isEmail(e)) return { ok: false, reason: 'invalid_email' };
    outEmail = e.toLowerCase();
  }
  if (p) {
    const sp = sanitizePhone(p);
    if (!sp || !isE164(sp)) return { ok: false, reason: 'invalid_phone' };
    outPhone = sp;
  }
  return { ok: true, email: outEmail, phone: outPhone };
}
