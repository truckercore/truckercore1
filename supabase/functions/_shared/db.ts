// supabase/functions/_shared/db.ts
// DB helpers: client factory and org scope checks.

import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON") ?? Deno.env.get("SUPABASE_ANON_KEY");
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export function getClient(role: 'service'|'anon' = 'service', authHeader?: string){
  if (role === 'service') return createClient(URL, SERVICE);
  if (!ANON) throw new Error('Missing SUPABASE_ANON (fallback SUPABASE_ANON_KEY not set)');
  return createClient(URL, ANON, { global: { headers: { Authorization: authHeader ?? '' } } });
}

export async function ensureOrgScope(db: any, org_id: string, requester: string): Promise<void> {
  if (!org_id || !requester) throw new Error('forbidden');
  const { data, error } = await db
    .from('fleet_members')
    .select('role')
    .eq('org_id', org_id)
    .eq('user_id', requester)
    .limit(1)
    .maybeSingle();
  if (error || !data) throw new Error('forbidden');
  const role = (data as any).role as string;
  if (!['admin','dispatcher','safety'].includes(role)) throw new Error('forbidden');
}

export async function findExistingInviteOrMember(db: any, org_id: string, email?: string, phone?: string){
  // Check existing member
  if (email || phone){
    const { data: inv } = await db
      .from('driver_invites')
      .select('id,status,email,phone')
      .eq('org_id', org_id)
      .or([(email?`email.eq.${email}`:''), (phone?`phone.eq.${phone}`:'')].filter(Boolean).join(','))
      .limit(1);
    if (inv && inv.length) return { kind: 'invite', row: inv[0] } as const;
  }
  // Member by email/phone requires joining auth; skip for now.
  return null;
}
