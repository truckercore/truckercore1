// supabase/functions/_shared/validation.ts
// Shared CSV validation helpers for driver imports.

export type ValidatedRow = {
  name: string;
  email?: string;
  phone?: string;
  role: 'driver'|'dispatcher'|'safety'|'admin';
  license_no?: string;
  truck_id?: string;
};

export const ROLE_SET = new Set(['driver','dispatcher','safety','admin']);
export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export const PHONE_RE = /^\+?[1-9]\d{6,14}$/; // E.164 light

export function normalizeHeader(h: string): string {
  return h.trim().toLowerCase().replace(/\s+/g, '_');
}

export function mapRow(raw: Record<string, unknown>): ValidatedRow {
  const get = (k: string, ...alts: string[]) => {
    for (const key of [k, ...alts]) {
      const v = raw[key] ?? raw[normalizeHeader(key) as keyof typeof raw];
      if (typeof v === 'string' && v.trim()) return v.trim();
    }
    return undefined;
  };

  const name = get('name', 'full_name') ?? '';
  const email = get('email');
  const phone = get('phone', 'mobile', 'phone_number');
  const role = (get('role') ?? 'driver').toLowerCase() as ValidatedRow['role'];
  const license_no = get('license_no', 'license', 'cdl');
  const truck_id = get('truck_id', 'truck');

  return { name, email, phone, role, license_no, truck_id };
}

export function validateRow(row: ValidatedRow): string[] {
  const errs: string[] = [];
  if (!row.name || row.name.length < 2 || row.name.length > 80) errs.push('invalid_name');
  if (!row.email && !row.phone) errs.push('missing_contact');
  if (row.email) {
    const e = row.email.trim().toLowerCase();
    if (!EMAIL_RE.test(e)) errs.push('invalid_email_format');
    else row.email = e;
  }
  if (row.phone) {
    const p = row.phone.trim();
    if (!PHONE_RE.test(p)) errs.push('invalid_phone_format');
    else row.phone = p;
  }
  if (!ROLE_SET.has(row.role)) errs.push('invalid_role');
  if (row.license_no && (row.license_no.length < 3 || row.license_no.length > 32)) errs.push('invalid_license_no');
  if (row.truck_id && !/^[0-9a-fA-F-]{8,}$/.test(row.truck_id)) errs.push('invalid_truck_id');
  return errs;
}
