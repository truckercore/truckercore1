import type { Load } from '../../types/freight';
import { supabase, assertDbConfigured } from './supabaseClient';

export async function listLoads(): Promise<Load[]> {
  const cfg = assertDbConfigured();
  if (!cfg.ok) return [];
  const { data, error } = await supabase
    .from('loads')
    .select(`
      id, customer_id, customer_name, carrier_id, carrier_name, status,
      pickup_address, pickup_city, pickup_state, pickup_zip,
      delivery_address, delivery_city, delivery_state, delivery_zip,
      pickup_date, delivery_date, equipment_type, weight, distance,
      commodity, customer_rate, carrier_rate, margin, margin_percentage,
      special_instructions, created_at, updated_at
    `)
    .limit(200);
  if (error) {
    console.error('listLoads error', error);
    return [];
  }
  return (data || []).map(rowToLoad);
}

export async function createLoad(load: Load): Promise<boolean> {
  const cfg = assertDbConfigured();
  if (!cfg.ok) return false;
  const { error } = await supabase.from('loads').insert(loadToRow(load));
  if (error) {
    console.error('createLoad error', error);
    return false;
  }
  return true;
}

function rowToLoad(r: any): Load {
  return {
    id: r.id,
    customerId: r.customer_id,
    customerName: r.customer_name,
    carrierId: r.carrier_id ?? undefined,
    carrierName: r.carrier_name ?? undefined,
    status: r.status,
    pickupLocation: {
      address: r.pickup_address, city: r.pickup_city, state: r.pickup_state, zipCode: r.pickup_zip,
    },
    deliveryLocation: {
      address: r.delivery_address, city: r.delivery_city, state: r.delivery_state, zipCode: r.delivery_zip,
    },
    pickupDate: new Date(r.pickup_date).toISOString(),
    deliveryDate: new Date(r.delivery_date).toISOString(),
    equipmentType: r.equipment_type,
    weight: Number(r.weight),
    distance: Number(r.distance),
    commodity: r.commodity,
    customerRate: Number(r.customer_rate),
    carrierRate: r.carrier_rate != null ? Number(r.carrier_rate) : undefined,
    margin: r.margin != null ? Number(r.margin) : undefined,
    marginPercentage: r.margin_percentage != null ? Number(r.margin_percentage) : undefined,
    specialInstructions: r.special_instructions ?? undefined,
    documents: [],
    createdAt: new Date(r.created_at).toISOString(),
    updatedAt: new Date(r.updated_at).toISOString(),
  };
}

function loadToRow(l: Load) {
  return {
    id: l.id,
    customer_id: l.customerId,
    customer_name: l.customerName,
    carrier_id: l.carrierId ?? null,
    carrier_name: l.carrierName ?? null,
    status: l.status,
    pickup_address: l.pickupLocation.address,
    pickup_city: l.pickupLocation.city,
    pickup_state: l.pickupLocation.state,
    pickup_zip: l.pickupLocation.zipCode,
    delivery_address: l.deliveryLocation.address,
    delivery_city: l.deliveryLocation.city,
    delivery_state: l.deliveryLocation.state,
    delivery_zip: l.deliveryLocation.zipCode,
    pickup_date: l.pickupDate,
    delivery_date: l.deliveryDate,
    equipment_type: l.equipmentType,
    weight: l.weight,
    distance: l.distance,
    commodity: l.commodity,
    customer_rate: l.customerRate,
    carrier_rate: l.carrierRate ?? null,
    margin: l.margin ?? null,
    margin_percentage: l.marginPercentage ?? null,
    special_instructions: l.specialInstructions ?? null,
    created_at: l.createdAt,
    updated_at: l.updatedAt,
  };
}
