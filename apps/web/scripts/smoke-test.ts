/**
 * Automated Smoke Test Helper
 * Run with: npm run test:smoke (from apps/web)
 */

import { RateCalculator } from '../src/utils/rateCalculator';
import { CarrierMatcher } from '../src/utils/carrierMatcher';
import type { Carrier, Load } from '../src/types/freight';

console.log('🧪 Starting Smoke Tests...\n');

// Test 1: Rate Calculator
console.log('📊 Test 1: Rate Calculator');
try {
  const calculation = RateCalculator.calculateRate(500, 40000, 'dry_van');
  console.assert(calculation.baseRate === 1000, 'Base rate should be $1000');
  console.assert(calculation.fuelSurcharge === 150, 'Fuel surcharge should be $150');
  console.assert(calculation.totalCarrierRate === 1150, 'Total carrier rate should be $1150');
  console.assert(Math.abs(calculation.marginPercentage - 20) < 0.1, 'Margin should be ~20%');
  console.log('✅ Rate Calculator: PASSED\n');
} catch (error) {
  console.error('❌ Rate Calculator: FAILED', error);
}

// Test 2: Equipment Multipliers
console.log('📊 Test 2: Equipment Multipliers');
try {
  const dryVan = RateCalculator.calculateRate(100, 40000, 'dry_van');
  const reefer = RateCalculator.calculateRate(100, 40000, 'reefer');
  console.assert(reefer.baseRate === dryVan.baseRate * 1.3, 'Reefer should be 1.3x dry van');
  console.log('✅ Equipment Multipliers: PASSED\n');
} catch (error) {
  console.error('❌ Equipment Multipliers: FAILED', error);
}

// Test 3: Weight Adjustment
console.log('📊 Test 3: Weight Adjustment');
try {
  const light = RateCalculator.calculateRate(100, 30000, 'dry_van');
  const heavy = RateCalculator.calculateRate(100, 45000, 'dry_van');
  console.assert(heavy.baseRate === Math.round(light.baseRate * 1.1 * 100) / 100, 'Heavy loads should be 1.1x');
  console.log('✅ Weight Adjustment: PASSED\n');
} catch (error) {
  console.error('❌ Weight Adjustment: FAILED', error);
}

// Test 4: Margin Calculation
console.log('📊 Test 4: Margin Calculation');
try {
  const margin = RateCalculator.calculateMargin(1000, 800);
  console.assert(margin.margin === 200, 'Margin should be $200');
  console.assert(Math.abs(margin.marginPercentage - 20) < 0.01, 'Margin % should be 20%');
  console.log('✅ Margin Calculation: PASSED\n');
} catch (error) {
  console.error('❌ Margin Calculation: FAILED', error);
}

// Test 5: Distance Calculation
console.log('📊 Test 5: Distance Calculation');
try {
  // Dallas to Denver: ~780 miles
  const distance = RateCalculator.calculateDistance(32.7767, -96.797, 39.7392, -104.9903);
  console.assert(distance > 700 && distance < 850, 'Dallas-Denver should be ~780 miles');
  console.log(`   Calculated distance: ${distance} miles`);
  console.log('✅ Distance Calculation: PASSED\n');
} catch (error) {
  console.error('❌ Distance Calculation: FAILED', error);
}

// Test 6: Carrier Matching
console.log('📊 Test 6: Carrier Matching');
try {
  const mockCarriers: Carrier[] = [
    {
      id: 'CARR-1',
      companyName: 'Top Carrier',
      mcNumber: '123456',
      dotNumber: '7891011',
      contactName: 'John Doe',
      email: 'john@carrier.com',
      phone: '5551234567',
      status: 'approved',
      rating: 4.8,
      totalLoads: 150,
      onTimeDeliveryRate: 96,
      insuranceVerified: true,
      insuranceExpiry: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      authorityStatus: 'active',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
    {
      id: 'CARR-2',
      companyName: 'Average Carrier',
      mcNumber: '234567',
      dotNumber: '8901112',
      contactName: 'Jane Smith',
      email: 'jane@carrier.com',
      phone: '5552345678',
      status: 'approved',
      rating: 3.5,
      totalLoads: 30,
      onTimeDeliveryRate: 88,
      insuranceVerified: true,
      insuranceExpiry: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      authorityStatus: 'active',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    },
  ];

  const load: Load = {
    id: 'LOAD-TEST',
    customerId: 'CUST-1',
    customerName: 'Test Customer',
    status: 'posted',
    pickupLocation: { address: 'A', city: 'Dallas', state: 'TX', zipCode: '75201' },
    deliveryLocation: { address: 'B', city: 'Denver', state: 'CO', zipCode: '80201' },
    pickupDate: new Date().toISOString(),
    deliveryDate: new Date().toISOString(),
    equipmentType: 'dry_van',
    weight: 40000,
    distance: 780,
    commodity: 'Widgets',
    customerRate: 2000,
    documents: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const matches = CarrierMatcher.findMatchingCarriers(load, mockCarriers);
  console.assert(matches.length === 2, 'Should return two matches');
  console.assert(matches[0].score >= matches[1].score, 'Results should be sorted by score');
  console.log('✅ Carrier Matching: PASSED\n');
} catch (error) {
  console.error('❌ Carrier Matching: FAILED', error);
}

console.log('🏁 Smoke tests complete.');
