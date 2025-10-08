export interface Expense {
  id: string;
  date: Date;
  category: ExpenseCategory;
  amount: number;
  description: string;
  receiptUrl?: string;
  mileage?: number;
  fuelGallons?: number;
  state?: string;
  deductible: boolean;
  metadata?: Record<string, any>;
}

export type ExpenseCategory =
  | 'fuel'
  | 'maintenance'
  | 'insurance'
  | 'tolls'
  | 'permits'
  | 'depreciation'
  | 'meals'
  | 'lodging'
  | 'other';

export interface Revenue {
  id: string;
  date: Date;
  loadId?: string;
  amount: number;
  miles: number;
  description: string;
  invoiceNumber?: string;
  paidDate?: Date;
  status: 'pending' | 'paid' | 'overdue';
}

export interface IFTAReport {
  quarter: string;
  year: number;
  stateBreakdown: StateIFTA[];
  totalTax: number;
}

export interface StateIFTA {
  state: string;
  miles: number;
  fuelGallons: number;
  taxRate: number;
  taxOwed: number;
}

export interface Form2290Data {
  year: number;
  vin: string;
  grossWeight: number;
  firstUsedMonth: string;
  taxAmount: number;
  status: 'pending' | 'filed' | 'paid';
}

export interface TaxEstimate {
  quarter: string;
  year: number;
  estimatedIncome: number;
  estimatedExpenses: number;
  selfEmploymentTax: number;
  incomeTax: number;
  totalDue: number;
}

export interface BusinessMetrics {
  costPerMile: number;
  revenuePerMile: number;
  profitPerMile: number;
  breakEvenMiles: number;
  operatingRatio: number;
}

export interface LaneProfitability {
  origin: string;
  destination: string;
  totalLoads: number;
  averageRevenue: number;
  averageMiles: number;
  averageCost: number;
  profitMargin: number;
  revenuePerMile: number;
}

export interface Invoice {
  id: string;
  invoiceNumber: string;
  date: Date;
  dueDate: Date;
  clientName: string;
  clientAddress: string;
  items: InvoiceItem[];
  subtotal: number;
  tax: number;
  total: number;
  status: 'draft' | 'sent' | 'paid' | 'overdue';
}

export interface InvoiceItem {
  description: string;
  quantity: number;
  rate: number;
  amount: number;
}

export interface Form1099Data {
  year: number;
  payerName: string;
  payerEIN: string;
  recipientName: string;
  recipientSSN: string;
  nonemployeeCompensation: number;
}
