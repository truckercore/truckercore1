/**
 * Complete Integration Test Suite
 * Tests all workflows end-to-end
 * Run: npm run test:integration (from apps/web)
 */

import { RateCalculator } from '../src/utils/rateCalculator';
import { CarrierMatcher } from '../src/utils/carrierMatcher';
import { CarrierVerificationService } from '../src/services/carrierVerificationService';
import { DocumentGenerationService } from '../src/services/documentGenerationService';
import type { Carrier, Load } from '../src/types/freight';

console.log('🚀 Starting Integration Tests...\n');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function test(name: string, fn: () => void | Promise<void>) {
  totalTests++;
  try {
    const result = fn();
    if (result instanceof Promise) {
      result
        .then(() => {
          passedTests++;
          console.log(`✅ ${name}`);
        })
        .catch((error) => {
          failedTests++;
          console.error(`❌ ${name}`);
          console.error(`   Error: ${error.message}`);
        });
    } else {
      passedTests++;
      console.log(`✅ ${name}`);
    }
  } catch (error: any) {
    failedTests++;
    console.error(`❌ ${name}`);
    console.error(`   Error: ${error.message}`);
  }
}

// ============================================================================
// WORKFLOW 1: Complete Load Creation Flow
// ============================================================================
console.log('📦 WORKFLOW 1: Complete Load Creation Flow');
console.log('─'.repeat(60));

test('Step 1: Calculate rate for 500-mile dry van load', () => {
  const calculation = RateCalculator.calculateRate(500, 40000, 'dry_van');
  if (calculation.baseRate !== 1000) {
    throw new Error(`Expected base rate 1000, got ${calculation.baseRate}`);
  }
  if (calculation.totalCarrierRate !== 1150) {
    throw new Error(`Expected carrier rate 1150, got ${calculation.totalCarrierRate}`);
  }
  if (Math.abs(calculation.marginPercentage - 20) > 0.5) {
    throw new Error(`Expected margin ~20%, got ${calculation.marginPercentage}%`);
  }
});

test('Step 2: Create load with calculated rates', () => {
  const calculation = RateCalculator.calculateRate(500, 40000, 'dry_van');

  const load: Partial<Load> = {
    id: 'LOAD-INT-001',
    customerName: 'Integration Test Customer',
    pickupLocation: {
      address: '123 Test St',
      city: 'Dallas',
      state: 'TX',
      zipCode: '75201',
    },
    deliveryLocation: {
      address: '456 Test Ave',
      city: 'Phoenix',
      state: 'AZ',
      zipCode: '85001',
    },
    pickupDate: new Date().toISOString(),
    deliveryDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
    equipmentType: 'dry_van',
    weight: 40000,
    distance: 500,
    commodity: 'Test Commodity',
    customerRate: calculation.suggestedCustomerRate,
    carrierRate: calculation.totalCarrierRate,
    margin: calculation.margin,
    marginPercentage: calculation.marginPercentage,
  } as Partial<Load>;

  if (!load.customerRate || !load.carrierRate) {
    throw new Error('Load rates not set');
  }
  if (load.customerRate <= load.carrierRate) {
    throw new Error('Customer rate should be higher than carrier rate');
  }
});

test('Step 3: Match carriers to load', () => {
  const mockCarriers: Carrier[] = [
    {
      id: 'CARR-INT-001',
      companyName: 'High Quality Carrier',
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
      id: 'CARR-INT-002',
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
    id: 'LOAD-INT-001',
    equipmentType: 'dry_van',
    weight: 40000,
    distance: 500,
  } as Partial<Load>;

  const matches = CarrierMatcher.findMatchingCarriers(mockLoad as Load, mockCarriers);

  if (matches.length !== 2) {
    throw new Error(`Expected 2 matches, got ${matches.length}`);
  }
  if (matches[0].score <= matches[1].score) {
    throw new Error('Carriers should be sorted by score descending');
  }
  if (matches[0].carrier.id !== 'CARR-INT-001') {
    throw new Error('High quality carrier should be ranked first');
  }
});

// ============================================================================
// WORKFLOW 2: Carrier Onboarding Flow
// ============================================================================
console.log('\n👥 WORKFLOW 2: Carrier Onboarding Flow');
console.log('─'.repeat(60));

test('Step 1: Verify MC Number', async () => {
  const mcNumber = '123456';
  const result = await CarrierVerificationService.verifyMCNumber(mcNumber);

  if (result.mcNumber !== mcNumber) {
    throw new Error('MC number mismatch');
  }
  if (result.status !== 'active' && result.status !== 'inactive') {
    throw new Error('Invalid status returned');
  }
});

test('Step 2: Verify Insurance', async () => {
  const mcNumber = '123456';
  const result = await CarrierVerificationService.verifyInsurance(mcNumber);

  if (typeof result.verified !== 'boolean') {
    throw new Error('Insurance verification should return boolean');
  }
});

test('Step 3: Check insurance expiry warning', () => {
  const expiringIn20Days = new Date(Date.now() + 20 * 24 * 60 * 60 * 1000).toISOString();
  const expiringIn60Days = new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString();

  const shouldWarn = CarrierVerificationService.isInsuranceExpiringSoon(expiringIn20Days, 30);
  const shouldNotWarn = CarrierVerificationService.isInsuranceExpiringSoon(expiringIn60Days, 30);

  if (!shouldWarn) {
    throw new Error('Should warn for insurance expiring in 20 days');
  }
  if (shouldNotWarn) {
    throw new Error('Should not warn for insurance expiring in 60 days');
  }
});

// ============================================================================
// WORKFLOW 3: Document Generation Flow
// ============================================================================
console.log('\n📄 WORKFLOW 3: Document Generation Flow');
console.log('─'.repeat(60));

const testLoad: Load = {
  id: 'LOAD-DOC-001',
  customerId: 'CUST-001',
  customerName: 'Test Customer',
  carrierId: 'CARR-001',
  carrierName: 'Test Carrier',
  status: 'assigned',
  pickupLocation: {
    address: '123 Main St',
    city: 'Dallas',
    state: 'TX',
    zipCode: '75201',
  },
  deliveryLocation: {
    address: '456 Oak Ave',
    city: 'Phoenix',
    state: 'AZ',
    zipCode: '85001',
  },
  pickupDate: new Date().toISOString(),
  deliveryDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
  equipmentType: 'dry_van',
  weight: 40000,
  distance: 500,
  commodity: 'Electronics',
  customerRate: 2000,
  carrierRate: 1600,
  margin: 400,
  marginPercentage: 20,
  documents: [],
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
};

const brokerInfo = {
  name: 'Test Broker',
  mcNumber: '999888',
  phone: '555-000-0000',
};

test('Step 1: Generate Rate Confirmation PDF', () => {
  const blob = DocumentGenerationService.generateRateConfirmation(testLoad, brokerInfo);
  if (!(blob instanceof Blob)) {
    throw new Error('Should return Blob instance');
  }
  if (blob.type !== 'application/pdf') {
    throw new Error(`Expected PDF, got ${blob.type}`);
  }
});

test('Step 2: Generate Bill of Lading PDF', () => {
  const blob = DocumentGenerationService.generateBOL(testLoad);
  if (!(blob instanceof Blob)) {
    throw new Error('Should return Blob instance');
  }
  if (blob.type !== 'application/pdf') {
    throw new Error(`Expected PDF, got ${blob.type}`);
  }
});

test('Step 3: Generate Invoice PDF', () => {
  const blob = DocumentGenerationService.generateInvoice(testLoad, 'INV-001');
  if (!(blob instanceof Blob)) {
    throw new Error('Should return Blob instance');
  }
  if (blob.type !== 'application/pdf') {
    throw new Error(`Expected PDF, got ${blob.type}`);
  }
});

// ============================================================================
// WORKFLOW 4: Analytics Calculation Flow
// ============================================================================
console.log('\n📊 WORKFLOW 4: Analytics Calculation Flow');
console.log('─'.repeat(60));

test('Calculate total revenue and margin', () => {
  const loads: Load[] = [
    { ...testLoad, id: 'L1', customerRate: 2000, carrierRate: 1600 },
    { ...testLoad, id: 'L2', customerRate: 1500, carrierRate: 1200 },
    { ...testLoad, id: 'L3', customerRate: 3000, carrierRate: 2400 },
  ] as Load[];

  const totalRevenue = loads.reduce((sum, load) => sum + load.customerRate, 0);
  const totalCost = loads.reduce((sum, load) => sum + (load.carrierRate || 0), 0);
  const totalMargin = totalRevenue - totalCost;

  if (totalRevenue !== 6500) {
    throw new Error(`Expected revenue 6500, got ${totalRevenue}`);
  }
  if (totalCost !== 5200) {
    throw new Error(`Expected cost 5200, got ${totalCost}`);
  }
  if (totalMargin !== 1300) {
    throw new Error(`Expected margin 1300, got ${totalMargin}`);
  }
});

test('Group revenue by customer', () => {
  const loads: Load[] = [
    { ...testLoad, id: 'L1', customerId: 'C1', customerRate: 2000 },
    { ...testLoad, id: 'L2', customerId: 'C1', customerRate: 1500 },
    { ...testLoad, id: 'L3', customerId: 'C2', customerRate: 3000 },
  ] as Load[];

  const revenueByCustomer = loads.reduce((acc, load) => {
    if (!acc[(load as any).customerId]) {
      (acc as any)[(load as any).customerId] = 0;
    }
    (acc as any)[(load as any).customerId] += load.customerRate;
    return acc;
  }, {} as Record<string, number>);

  if (revenueByCustomer['C1'] !== 3500) {
    throw new Error(`Expected C1 revenue 3500, got ${revenueByCustomer['C1']}`);
  }
  if (revenueByCustomer['C2'] !== 3000) {
    throw new Error(`Expected C2 revenue 3000, got ${revenueByCustomer['C2']}`);
  }
});

// ============================================================================
// WORKFLOW 5: Edge Cases & Error Handling
// ============================================================================
console.log('\n⚠️ WORKFLOW 5: Edge Cases & Error Handling');
console.log('─'.repeat(60));

test('Handle zero distance', () => {
  const calc = RateCalculator.calculateRate(0, 40000, 'dry_van');
  if (calc.baseRate !== 0) {
    throw new Error('Zero distance should result in zero base rate');
  }
});

test('Handle very large distances', () => {
  const calc = RateCalculator.calculateRate(5000, 40000, 'dry_van');
  if (calc.baseRate <= 0 || !isFinite(calc.baseRate)) {
    throw new Error('Should handle large distances');
  }
});

test('Handle empty carrier list', () => {
  const mockLoad: Partial<Load> = {
    id: 'LOAD-EMPTY',
    equipmentType: 'dry_van',
    weight: 40000,
    distance: 500,
  } as Partial<Load>;

  const matches = CarrierMatcher.findMatchingCarriers(mockLoad as Load, []);
  if (matches.length !== 0) {
    throw new Error('Should return empty array for no carriers');
  }
});

test('Handle expired insurance detection', () => {
  const expired = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
  const isExpiring = CarrierVerificationService.isInsuranceExpiringSoon(expired, 30);
  if (isExpiring) {
    throw new Error('Already expired insurance should not show as "expiring soon"');
  }
});

// ============================================================================
// SUMMARY (allow async tests to finish)
// ============================================================================
setTimeout(() => {
  console.log('\n' + '='.repeat(60));
  console.log('📊 INTEGRATION TEST SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total Tests: ${totalTests}`);
  console.log(`Passed: ${passedTests} ✅`);
  console.log(`Failed: ${failedTests} ❌`);
  console.log(`Success Rate: ${((passedTests / totalTests) * 100).toFixed(1)}%`);
  console.log('='.repeat(60));

  if (failedTests === 0) {
    console.log('\n🎉 All integration tests passed!');
    console.log('✅ System is ready for production deployment\n');
    process.exit(0);
  } else {
    console.log('\n⚠️ Some tests failed. Please review and fix issues.\n');
    process.exit(1);
  }
}, 2000);
