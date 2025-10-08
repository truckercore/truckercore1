/**
 * Automated Smoke Test Helper
 * Run with: npm run test:smoke (from apps/web)
 */

import { RateCalculator } from '../utils/rateCalculator';
import { CarrierMatcher } from '../utils/carrierMatcher';
import type { Carrier, Load } from '../types/freight';

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

  const mockLoad: Partial<Load> = {
    id: 'LOAD-1',
    equipmentType: 'dry_van',
    weight: 40000,
    distance: 500,
    customerId: 'CUST-1',
    customerName: 'Test',
    pickupLocation: { address: '', city: '', state: 'TX', zipCode: '00000' },
    deliveryLocation: { address: '', city: '', state: 'TX', zipCode: '00000' },
    pickupDate: new Date().toISOString(),
    deliveryDate: new Date().toISOString(),
    commodity: 'Goods',
    customerRate: 0,
    documents: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    status: 'posted',
  };

  const matches = CarrierMatcher.findMatchingCarriers(mockLoad as Load, mockCarriers);
  console.assert(matches.length === 2, 'Should return 2 carriers');
  console.assert(matches[0].carrier.id === 'CARR-1', 'Top carrier should be first');
  console.assert(matches[0].score > matches[1].score, 'Scores should be sorted');
  console.log(`   Top carrier score: ${matches[0].score}`);
  console.log(`   Second carrier score: ${matches[1].score}`);
  console.log('✅ Carrier Matching: PASSED\n');
} catch (error) {
  console.error('❌ Carrier Matching: FAILED', error);
}

// Test 7: Scoring Algorithm
console.log('📊 Test 7: Scoring Algorithm');
try {
  const perfectCarrier: Carrier = {
    id: 'CARR-PERFECT',
    companyName: 'Perfect Carrier',
    mcNumber: '999999',
    dotNumber: '9999999',
    contactName: 'Perfect Driver',
    email: 'perfect@carrier.com',
    phone: '5559999999',
    status: 'approved',
    rating: 5.0, // 30 points
    totalLoads: 200, // 20 points
    onTimeDeliveryRate: 100, // 30 points
    insuranceVerified: true, // 20 points
    insuranceExpiry: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
    authorityStatus: 'active',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const mockLoad2: Partial<Load> = {
    id: 'LOAD-TEST',
    equipmentType: 'dry_van',
    weight: 40000,
    distance: 500,
    customerId: 'CUST-1',
    customerName: 'Test',
    pickupLocation: { address: '', city: '', state: 'TX', zipCode: '00000' },
    deliveryLocation: { address: '', city: '', state: 'TX', zipCode: '00000' },
    pickupDate: new Date().toISOString(),
    deliveryDate: new Date().toISOString(),
    commodity: 'Goods',
    customerRate: 0,
    documents: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    status: 'posted',
  };

  const matches2 = CarrierMatcher.findMatchingCarriers(mockLoad2 as Load, [perfectCarrier]);
  console.assert(matches2[0].score === 100, 'Perfect carrier should score 100');
  console.log(`   Perfect carrier score: ${matches2[0].score}`);
  console.log('✅ Scoring Algorithm: PASSED\n');
} catch (error) {
  console.error('❌ Scoring Algorithm: FAILED', error);
}

// ============================================================================
// TEST 8: Carrier Verification Service
// =========================================================================
console.log('📊 Test 8: Carrier Verification Service');
try {
  const mcNumber = '123456';
  const fmcsaResult = await (await import('../services/carrierVerificationService')).CarrierVerificationService.verifyMCNumber(mcNumber);
  console.assert(fmcsaResult.mcNumber === mcNumber, 'MC number should match');
  console.assert(fmcsaResult.status === 'active', 'Status should be active for valid MC');
  const insurance = await (await import('../services/carrierVerificationService')).CarrierVerificationService.verifyInsurance(mcNumber);
  console.assert(insurance.verified === true, 'Insurance should be verified in mock');
  console.log('✅ Carrier Verification Service: PASSED\n');
} catch (error) {
  console.error('❌ Carrier Verification Service: FAILED', error);
}

// ============================================================================
// TEST 9: Document Generation Service (PDF)
// ============================================================================
console.log('📊 Test 9: Document Generation Service (PDF)');
try {
  const { DocumentGenerationService } = await import('../services/documentGenerationService');
  const sampleLoad = {
    id: 'LOAD-DOC-1',
    customerId: 'CUST-1',
    customerName: 'Test Customer',
    carrierId: 'CARR-1',
    carrierName: 'Test Carrier',
    status: 'assigned',
    pickupLocation: { address: '123', city: 'Dallas', state: 'TX', zipCode: '75201' },
    deliveryLocation: { address: '456', city: 'Phoenix', state: 'AZ', zipCode: '85001' },
    pickupDate: new Date().toISOString(),
    deliveryDate: new Date(Date.now() + 2 * 86400000).toISOString(),
    equipmentType: 'dry_van',
    weight: 40000,
    distance: 1000,
    commodity: 'Goods',
    customerRate: 2000,
    carrierRate: 1600,
    margin: 400,
    marginPercentage: 20,
    documents: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  } as any;

  const brokerInfo = { name: 'Test Broker', mcNumber: '999888', phone: '555-000-0000' };

  const rc = DocumentGenerationService.generateRateConfirmation(sampleLoad, brokerInfo);
  const bol = DocumentGenerationService.generateBOL(sampleLoad);
  const inv = DocumentGenerationService.generateInvoice(sampleLoad, 'INV-001');

  console.assert(rc instanceof Blob, 'Rate Confirmation should be a Blob');
  console.assert(bol instanceof Blob, 'BOL should be a Blob');
  console.assert(inv instanceof Blob, 'Invoice should be a Blob');
  console.log('✅ Document Generation Service (PDF): PASSED\n');
} catch (error) {
  console.error('❌ Document Generation Service (PDF): FAILED', error);
}

console.log('🎉 All Smoke Tests Completed!');
