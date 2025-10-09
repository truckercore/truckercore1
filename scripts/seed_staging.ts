// scripts/seed_staging.ts
// Deno script to seed staging with providers, locations, services, and an open roadside request.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const url = Deno.env.get('SUPABASE_URL')!
const key = Deno.env.get('SUPABASE_SERVICE_ROLE')!
const db = createClient(url, key, { auth: { persistSession: false }})

const ORG = Deno.env.get('SEED_ORG_ID') || '00000000-0000-0000-0000-000000000000'

async function upsert(table: string, rows: any[]) {
  for (const r of rows) {
    const { error } = await db.from(table).upsert(r as any)
    if (error) throw new Error(`${table}: ${error.message}`)
  }
}

function uuid() { try { return crypto.randomUUID() } catch { return (self as any).crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}` } }

// Seed providers
await upsert('providers', [
  { id: uuid(), org_id: ORG, name: 'RoadRescue East', phone: '+15550001' },
  { id: uuid(), org_id: ORG, name: 'TowMasters', phone: '+15550002' },
])

// Seed locations
await upsert('locations', [
  { id: uuid(), org_id: ORG, name: 'I-80 Fuel Plaza', lat: 41.613, lng: -93.581, address: 'Des Moines, IA' },
  { id: uuid(), org_id: ORG, name: 'US-30 Travel Center', lat: 40.825, lng: -96.707, address: 'Lincoln, NE' },
])

// Seed services for each provider
const providers = (await db.from('providers').select('id').eq('org_id', ORG)).data || []
for (const p of providers) {
  await upsert('provider_services', [
    { provider_id: (p as any).id, service_type: 'tow', base_price_cents: 15000 },
    { provider_id: (p as any).id, service_type: 'tire', base_price_cents: 9000 },
    { provider_id: (p as any).id, service_type: 'jump', base_price_cents: 5000 },
  ])
}

// Seed an open roadside request for first location
const loc = (await db.from('locations').select('id').eq('org_id', ORG).limit(1).maybeSingle()).data
if (loc) {
  await upsert('roadside_requests', [{
    id: uuid(),
    org_id: ORG,
    location_id: (loc as any).id,
    service_type: 'tire',
    status: 'open',
    details: { truck: 'ABC-123', note: 'Blown tire on I-80 exit 137' },
    requested_by: '11111111-1111-1111-1111-111111111111'
  }])
}

console.log('Seeding complete')
