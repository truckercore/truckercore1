export interface Carrier {
  id: string;
  companyName: string;
  mcNumber: string;
  dotNumber: string;
  contactName: string;
  email: string;
  phone: string;
  status: 'pending' | 'approved' | 'rejected' | 'suspended';
  rating: number;
  totalLoads: number;
  onTimeDeliveryRate: number;
  insuranceVerified: boolean;
  insuranceExpiry: string;
  authorityStatus: 'active' | 'inactive';
  createdAt: string;
  updatedAt: string;
}

export interface Load {
  id: string;
  customerId: string;
  customerName: string;
  carrierId?: string;
  carrierName?: string;
  status: 'posted' | 'assigned' | 'in_transit' | 'delivered' | 'cancelled';
  pickupLocation: Location;
  deliveryLocation: Location;
  pickupDate: string;
  deliveryDate: string;
  equipmentType: 'dry_van' | 'reefer' | 'flatbed' | 'step_deck' | 'tanker';
  weight: number;
  distance: number;
  commodity: string;
  customerRate: number;
  carrierRate?: number;
  margin?: number;
  marginPercentage?: number;
  specialInstructions?: string;
  documents: LoadDocument[];
  createdAt: string;
  updatedAt: string;
}

export interface Location {
  address: string;
  city: string;
  state: string;
  zipCode: string;
  lat?: number;
  lng?: number;
}

export interface LoadDocument {
  id: string;
  type: 'rate_confirmation' | 'bol' | 'pod' | 'invoice' | 'other';
  fileName: string;
  fileUrl: string;
  uploadedAt: string;
  uploadedBy: string;
}

export interface RateConfirmation {
  loadId: string;
  brokerName: string;
  brokerMC: string;
  carrierName: string;
  carrierMC: string;
  pickupLocation: Location;
  deliveryLocation: Location;
  pickupDate: string;
  deliveryDate: string;
  commodity: string;
  weight: number;
  rate: number;
  termsAndConditions: string;
  generatedAt: string;
}

export interface Invoice {
  id: string;
  loadId: string;
  customerId: string;
  amount: number;
  status: 'draft' | 'sent' | 'paid' | 'overdue';
  issueDate: string;
  dueDate: string;
  paidDate?: string;
  paymentMethod?: string;
}

export interface CarrierPerformance {
  carrierId: string;
  totalLoads: number;
  onTimeDeliveries: number;
  lateDeliveries: number;
  cancelledLoads: number;
  averageRating: number;
  totalRevenue: number;
  onTimePercentage: number;
}

export interface LoadAnalytics {
  totalRevenue: number;
  totalCost: number;
  totalMargin: number;
  averageMarginPercentage: number;
  loadsByStatus: Record<string, number>;
  revenueByCustomer: Array<{ customerId: string; customerName: string; revenue: number }>;
  marginByLoad: Array<{ loadId: string; margin: number; marginPercentage: number }>;
}
