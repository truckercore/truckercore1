import type { Carrier } from '../../types/freight';
import { supabase, assertDbConfigured } from './supabaseClient';

export async function listCarriers(): Promise<Carrier[]> {
  const cfg = assertDbConfigured();
  if (!cfg.ok) return [];
  const { data, error } = await supabase
    .from('carriers')
    .select(`
      id, company_name, mc_number, dot_number, contact_name, email, phone,
      status, rating, total_loads, on_time_delivery_rate, insurance_verified,
      insurance_expiry, authority_status, created_at, updated_at
    `)
    .limit(200);
  if (error) {
    console.error('listCarriers error', error);
    return [];
  }
  return (data || []).map(rowToCarrier);
}

export async function createCarrier(c: Carrier): Promise<boolean> {
  const cfg = assertDbConfigured();
  if (!cfg.ok) return false;
  const { error } = await supabase.from('carriers').insert(carrierToRow(c));
  if (error) {
    console.error('createCarrier error', error);
    return false;
  }
  return true;
}

function rowToCarrier(r: any): Carrier {
  return {
    id: r.id,
    companyName: r.company_name,
    mcNumber: r.mc_number,
    dotNumber: r.dot_number,
    contactName: r.contact_name,
    email: r.email,
    phone: r.phone,
    status: r.status,
    rating: Number(r.rating),
    totalLoads: Number(r.total_loads),
    onTimeDeliveryRate: Number(r.on_time_delivery_rate),
    insuranceVerified: !!r.insurance_verified,
    insuranceExpiry: r.insurance_expiry ? new Date(r.insurance_expiry).toISOString() : '',
    authorityStatus: r.authority_status,
    createdAt: new Date(r.created_at).toISOString(),
    updatedAt: new Date(r.updated_at).toISOString(),
  };
}

function carrierToRow(c: Carrier) {
  return {
    id: c.id,
    company_name: c.companyName,
    mc_number: c.mcNumber,
    dot_number: c.dotNumber,
    contact_name: c.contactName,
    email: c.email,
    phone: c.phone,
    status: c.status,
    rating: c.rating,
    total_loads: c.totalLoads,
    on_time_delivery_rate: c.onTimeDeliveryRate,
    insurance_verified: c.insuranceVerified,
    insurance_expiry: c.insuranceExpiry || null,
    authority_status: c.authorityStatus,
    created_at: c.createdAt,
    updated_at: c.updatedAt,
  };
}
